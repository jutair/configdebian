#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# Verifica root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
[ ! -f "$INSTALLER_PATH" ] && INSTALLER_PATH="./openvpn-install.sh"

STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

# --- FUNÇÕES DE APOIO ---

veri_openvpn () {
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não instalado. Iniciando instalador...${SEM_COR}"
        sudo wget -P "$(dirname "$INSTALLER_PATH")" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
        sudo chmod +x "$INSTALLER_PATH"
        sudo "$INSTALLER_PATH"
    fi

    # Auto-detecção do Easy-RSA e PKI
    [ -d "/etc/openvpn/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/easy-rsa"
    [ -d "/etc/openvpn/server/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    
    # Valida estrutura básica
    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    if [ ! -f "$INDEX_FILE" ]; then
        sudo mkdir -p "$(dirname "$INDEX_FILE")"
        sudo touch "$INDEX_FILE"
    fi
}

# Função unificada para mover arquivos .ovpn para a home do usuário
sincronizar_arquivos() {
    DESTINO="/home/$USER_ATUAL/clientes_ovp"
    mkdir -p "$DESTINO"
    chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO"

    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)
    if [ -n "$ARQUIVOS" ]; then
        echo "$ARQUIVOS" | while read -r arq; do
            mv "$arq" "$DESTINO/"
            chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO/$(basename "$arq")"
            chmod 644 "$DESTINO/$(basename "$arq")"
        done
    fi
}

# --- FUNÇÕES DO MENU ---

user_online() {
    clear
    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${VERMELHO}Erro: Log não encontrado.${SEM_COR}"
    else
        LISTA=$(grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name")
        if [ -z "$LISTA" ]; then
            echo "Nenhum usuário conectado."
        else
            echo "$LISTA" | while read -r line; do
                USER=$(echo "$line" | cut -d',' -f2)
                IP_R=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
                IP_V=$(echo "$line" | cut -d',' -f4)
                DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')
                printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_R" "$IP_V" "$DESDE"
            done
        fi
    fi
    echo "---------------------------------------------------------------"
    read -p "Pressione ENTER para voltar..." dummy
}

user_consumo() {
    clear
    echo "==============================================================="
    echo "               CONSUMO DE DADOS (SESSÃO)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"
    
    grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
        USER=$(echo "$line" | cut -d',' -f2)
        RECV=$(echo "$line" | cut -d',' -f5)
        SENT=$(echo "$line" | cut -d',' -f6)
        
        RECV_MB=$(echo "scale=2; $RECV/1024/1024" | bc)
        SENT_MB=$(echo "scale=2; $SENT/1024/1024" | bc)
        TOTAL=$(echo "scale=2; ($RECV+$SENT)/1024/1024" | bc)
        
        printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL}MB"
    done
    read -p "Pressione ENTER para voltar..." dummy
}

user_gerencia() {
    while true; do
        clear
        echo "======================================"
        echo "      GERENCIAMENTO DE CLIENTES       "
        echo "======================================"
        echo "[1] Adicionar Cliente"
        echo "[2] Remover/Revogar Cliente"
        echo "[3] Listar todos (PKI)"
        echo "[4] Voltar ao Menu VPN"
        echo "======================================"
        read -n 1 -p "Opção: " OP_G
        echo ""

        case $OP_G in
            1)
                read -p "Nome do cliente: " CLIENT
                sudo "$INSTALLER_PATH" add "$CLIENT" # Ajustado para sintaxe padrão
                sincronizar_arquivos
                ;;
            2)
                sudo "$INSTALLER_PATH" revoke
                sincronizar_arquivos
                ;;
            3)
                clear
                echo "--- STATUS NO BANCO PKI ---"
                column -t -s ',' /etc/openvpn/server/easy-rsa/pki/index.txt
                read -p "ENTER..." d
                ;;
            4) return ;; # Volta para o menu_ovp
        esac
    done
}

# --- MENU PRINCIPAL DA VPN ---

menu_ovp() {
    # Busca IPs uma vez por entrada no menu para não lentificar o loop
    IP_INT=$(hostname -I | awk '{print $1}')
    IP_EXT=$(curl -4 -s ifconfig.me)

    while true; do
        clear
        echo "================================================================="
        echo "                     PAINEL OPEN VPN                             "
        echo " IP Interno: $IP_INT | IP Externo: $IP_EXT"
        echo "================================================================="
        echo "[1] Testar Velocidade (tun0)   [5] Monitorar Tráfego (Live)"
        echo "[2] Usuários Online            [6] Gerenciar Usuários/Certificados"
        echo "[3] Relatório Diário (vnstat)  [7] Voltar ao Menu Principal"
        echo "[4] Consumo da Sessão          [9] Sair do Sistema"
        echo "================================================================="
        read -n 1 -p "Digite a opção: " OPCAO
        echo ""

        case $OPCAO in
            1) testa_velocidade ;;
            2) user_online ;;
            3) vnstat -d -i tun0; read -p "ENTER..." d ;;
            4) user_consumo ;;
            5) monitora_tun ;; # Sua função com trap que já está no script
            6) user_gerencia ;;
            7) exec ./menu.sh ;; # VOLTA PARA O MENU PRINCIPAL LIMPANDO PROCESSO
            9) 
                echo "Encerrando..."
                kill -9 $(ps -o sess= -p $$) 
                ;;
            *) echo "Opção inválida"; sleep 1 ;;
        esac
    done
}

# --- EXECUÇÃO ---
veri_openvpn
sincronizar_arquivos
menu_ovp
