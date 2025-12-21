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
}

function user_online {
    clear
    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${VERMELHO}Erro: Arquivo de log não encontrado em $STATUS_FILE${SEM_COR}"
        echo "Dica: Verifique se 'status' está habilitado no seu server.conf"
        return
    fi

    grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
        USER=$(echo "$line" | cut -d',' -f2)
        IP_REAL=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
        IP_VPN=$(echo "$line" | cut -d',' -f4)
        DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')
        printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_REAL" "$IP_VPN" "$DESDE"
    done
    TOTAL=$(grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | wc -l)
    echo "---------------------------------------------------------------"
    echo "Total de conexões: $TOTAL"
    read -n 1 -s -p "Pressione qualquer tecla para voltar..."
}

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
    read -n 1 -s -p "Pressione qualquer tecla para voltar..."
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
            1) speedtest-cli --simple ;;
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
menu_ovp
