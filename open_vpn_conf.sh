#!/bin/bash

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
# O Angristan usa geralmente estes caminhos:
INSTALLER_PATH="/home/jutair/configdebian-main/openvpn-install.sh"
[ ! -f "$INSTALLER_PATH" ] && INSTALLER_PATH="./openvpn-install.sh"

# Caminho do LOG (Tenta os dois mais comuns)
STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

# --- FUNÇÕES ---
function veri_openvpn (){
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não instalado.${SEM_COR}"
        mkdir -p "/home/jutair/configdebian-main"
        wget -P "/home/jutair/configdebian-main" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
        chmod +x "$INSTALLER_PATH"
        sudo "$INSTALLER_PATH" install
    fi

    # Auto-detecção do Easy-RSA
    [ -d "/etc/openvpn/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/easy-rsa"
    [ -d "/etc/openvpn/server/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    
    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    
    # Garante o index.txt para evitar erros no menu
    if [ ! -f "$INDEX_FILE" ]; then
        mkdir -p "$(dirname "$INDEX_FILE")"
        touch "$INDEX_FILE"
        chmod 644 "$INDEX_FILE"
    fi
    echo -e "${VERDE}[OK] Sistema validado.${SEM_COR}\n"
    sleep 1
    menu_ovp
}
#################Função para ver usuários online#################
user_online() {
    clear
    # Define o caminho do log (prioriza o padrão do Angristan)
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "\033[31mErro: Arquivo de log não encontrado em $STATUS_FILE\033[0m"
        echo "Dica: Verifique se o OpenVPN está rodando."
    else
        # Processa o log - Formato CLIENT_LIST (vírgulas)
        # O grep busca apenas linhas de clientes ativos e ignora o cabeçalho
        LISTA=$(grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name")

        if [ -z "$LISTA" ]; then
            echo "Nenhum usuário conectado no momento."
        else
            echo "$LISTA" | while read -r line; do
                USER=$(echo "$line" | cut -d',' -f2)
                IP_REAL=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
                IP_VPN=$(echo "$line" | cut -d',' -f4)
                # Formata data e hora
                DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')

                printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_REAL" "$IP_VPN" "$DESDE"
            done
        fi

        echo "---------------------------------------------------------------"
        TOTAL=$(echo "$LISTA" | grep -v "^$" | wc -l)
        echo "Total de conexões: $TOTAL"
    fi

    echo "---------------------------------------------------------------"
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
#################Fim da função usuários online###################
function user_consumo {
    clear
    if [ ! -f "$STATUS_FILE" ]; then
        echo "Erro: Log não encontrado."
        return
    fi
    echo "==============================================================="
    echo "             CONSUMO DE DADOS (Sessão Atual)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"
    grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
        USER=$(echo "$line" | cut -d',' -f2)
        RECV_B=$(echo "$line" | cut -d',' -f5)
        SENT_B=$(echo "$line" | cut -d',' -f6)
        RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc)
        SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc)
        TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc)
        printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
    done
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
testa_velocidade() {
    clear
    echo "==============================================================="
    echo "           TESTE DE VELOCIDADE - INTERFACE TUN0"
    echo "==============================================================="
    
    # 1. Identifica o IP interno da interface tun0
    IP_TUN0=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    # 2. Verifica se a interface tun0 existe/está ativa
    if [ -z "$IP_TUN0" ]; then
        echo -e "\033[31mErro: Interface tun0 não encontrada ou VPN está offline.\033[0m"
        echo "Pressione ENTER para voltar..."
        read dummy
        return
    fi

    echo "IP da Interface: $IP_TUN0"
    echo "Aguarde, testando a conexão via túnel VPN..."
    echo "Isto pode levar até 1 minuto..."

    # 3. Executa o teste usando o parâmetro --source para forçar a tun0
    # Armazenamos em uma variável para processar os dados de uma vez só
    RESULTADO=$(speedtest-cli --source "$IP_TUN0" --simple 2>/dev/null)

    if [ -z "$RESULTADO" ]; then
        echo -e "\033[31mErro ao realizar o teste. Verifique se o speedtest-cli está instalado.\033[0m"
    else
        PING=$(echo "$RESULTADO" | grep "Ping" | awk '{print $2}')
        DOWNLOAD=$(echo "$RESULTADO" | grep "Download" | awk '{print $2}')
        UPLOAD=$(echo "$RESULTADO" | grep "Upload" | awk '{print $2}')

        clear
        echo "==============================================================="
        echo "           RESULTADO DA VELOCIDADE (TUN0)"
        echo "==============================================================="
        echo "Download : $DOWNLOAD Mbps"
        echo "Upload   : $UPLOAD Mbps"
        echo "Ping     : $PING ms"
        echo "==============================================================="
    fi
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
function monitora_tun (){
vnstat -d -i tun0; read -n 1 ;;
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
    menu_ovp
}
function menu_ovp {
    while true; do
        clear
        echo "================================================================="
        echo "                         Menu Open VPN:                          "
        echo "================================================================="
        echo "[1] Testar velocidade      [5] Monitorar tun0 (vnstat)"
        echo "[2] Usuários online        [6] Gerenciar usuário (Novo/Remover)"
        echo "[3] Relatório de consumo   [7] Sair"
        echo "[4] Consumo por usuário"
        echo "================================================================="
        read -n 1 -p "Digite a opção: " OPCAO
        echo ""
        case $OPCAO in
            1) testa_velocidade ;;
            2) user_online ;;
            3) vnstat -d -i tun0; read -n 1 ;;
            4) user_consumo ;;
            5) vnstat -l -i tun0 ;;
            6) 
                if [ -f "$INSTALLER_PATH" ]; then
                    sudo "$INSTALLER_PATH" interactive
                else
                    echo "Instalador não encontrado em $INSTALLER_PATH"
                    sleep 2
                fi
                ;;
            7) exit 0 ;;
        esac
    done
}

# --- INÍCIO ---
clear
veri_openvpn
