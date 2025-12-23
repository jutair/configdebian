#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# --- CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- VERIFICAÇÃO ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
    exit 1
fi

# --- CONFIGURAÇÃO E DETECÇÃO DO INSTALADOR ---
# Define os locais possíveis para busca
LOCAIS=(
    "/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
    "/home/$USER_ATUAL/openvpn-install.sh"
    "./openvpn-install.sh"
)

INSTALLER_PATH=""
for local in "${LOCAIS[@]}"; do
    if [ -f "$local" ]; then
        INSTALLER_PATH="$local"
        break
    fi
done

# Se não existir em nenhum lugar, baixa o oficial na home do usuário
if [ -z "$INSTALLER_PATH" ]; then
    INSTALLER_PATH="/home/$USER_ATUAL/openvpn-install.sh"
    echo -e "${AMARELO}[!] Instalador não localizado. Baixando em $INSTALLER_PATH...${SEM_COR}"
    wget -O "$INSTALLER_PATH" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x "$INSTALLER_PATH"
fi

STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"
INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

# --- FUNÇÕES DE APOIO ---

sincronizar_ovpns() {
    DESTINO="/home/$USER_ATUAL/clientes_ovp"
    mkdir -p "$DESTINO"
    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)
    if [ -n "$ARQUIVOS" ]; then
        echo "$ARQUIVOS" | while read -r arq; do
            mv "$arq" "$DESTINO/"
            chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO/$(basename "$arq")"
            chmod 644 "$DESTINO/$(basename "$arq")"
        done
    fi
}

# --- FUNÇÕES DE CONSUMO E STATUS ---

user_consumo() {
    clear
    echo "==============================================================="
    echo "               CONSUMO DE DADOS (Sessão Atual)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"
    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${VERMELHO}Erro: Log de status não encontrado.${SEM_COR}"
    else
        grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
            USER=$(echo "$line" | cut -d',' -f2)
            RECV_B=$(echo "$line" | cut -d',' -f5)
            SENT_B=$(echo "$line" | cut -d',' -f6)
            RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc 2>/dev/null || echo "0.00")
            SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc 2>/dev/null || echo "0.00")
            TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc 2>/dev/null || echo "0.00")
            printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
        done
    fi
    echo "---------------------------------------------------------------"
    read -p "Pressione ENTER para voltar..." dummy
}

user_online() {
    clear
    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"
    if [ -f "$STATUS_FILE" ]; then
        grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
            USER=$(echo "$line" | cut -d',' -f2)
            IP_R=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
            IP_V=$(echo "$line" | cut -d',' -f4)
            DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')
            printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_R" "$IP_V" "$DESDE"
        done
    else
        echo "Arquivo de log não encontrado."
    fi
    read -p "Pressione ENTER..." d
}

listar_usuarios_pki() {
    clear
    echo "==============================================================="
    echo "              RELATÓRIO DE USUÁRIOS (PKI)"
    echo "==============================================================="
    if [ -f "$INDEX_FILE" ]; then
        echo -e "${VERDE}[ ATIVOS ]${SEM_COR}"
        grep "^V" "$INDEX_FILE" | while read -r line; do
            USER=$(echo "$line" | awk -F'=' '{print $2}')
            DATA_RAW=$(echo "$line" | awk '{print $2}')
            DATA_BR="20${DATA_RAW:0:2}-${DATA_RAW:2:2}-${DATA_RAW:4:2}"
            printf "%-20s %-25s\n" "$USER" "$DATA_BR"
        done
    else
        echo "Banco de dados PKI não localizado."
    fi
    read -p "ENTER para voltar..." d
}

# --- MENU PRINCIPAL VPN ---

menu_ovp() {
    IP_INT=$(hostname -I | awk '{print $1}')
    IP_EXT=$(curl -4 -s ifconfig.me)

    while true; do
        clear
        echo "================================================================="
        echo "                      PAINEL OPEN VPN                            "
        echo " IP Interno: $IP_INT | IP Externo: $IP_EXT"
        echo "================================================================="
        echo "[1] Usuários Online            [5] Monitorar Tráfego (Live)"
        echo "[2] Gerenciar Usuários (Add/R) [6] Relatório de Consumo (MB)"
        echo "[3] Lista Completa (PKI)       [7] Voltar ao Menu Principal"
        echo "[4] Testar Velocidade tun0     [9] Sair do Sistema"
        echo "================================================================="
        read -n 1 -p "Opção: " OPCAO
        echo ""

        case $OPCAO in
            1) user_online ;;
            2) 
               # Tenta executar o instalador forçando o interpretador BASH
               if [ -f "$INSTALLER_PATH" ]; then
                   sudo bash "$INSTALLER_PATH"
               else
                   echo -e "${VERMELHO}Instalador não encontrado! Baixando...${SEM_COR}"
                   wget -O "/home/$USER_ATUAL/openvpn-install.sh" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
                   chmod +x "/home/$USER_ATUAL/openvpn-install.sh"
                   sudo bash "/home/$USER_ATUAL/openvpn-install.sh"
               fi
               sincronizar_ovpns
               ;;
            3) listar_usuarios_pki ;;
            4) 
               clear
               IP_TUN0=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
               if [ -n "$IP_TUN0" ]; then
                   speedtest-cli --source "$IP_TUN0" --simple
               else
                   echo "Erro: tun0 offline."
               fi
               read -p "ENTER..." d ;;
            5) 
               clear; trap '' INT
               ( trap - INT; vnstat -l -i tun0 )
               trap - INT; read -p "ENTER..." d ;;
            6) user_consumo ;;
            7) exec sudo ./menu.sh ;;
            9) kill -TERM -$(ps -o pgid= -p $$ | grep -o '[0-9]*'); exit 0 ;;
            *) echo "Opção Inválida"; sleep 1 ;;
        esac
    done
}

# --- INÍCIO DO SCRIPT ---
sincronizar_ovpns
menu_ovp
