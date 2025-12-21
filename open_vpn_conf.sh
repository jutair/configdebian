#!/bin/bash

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor execute esse script como sudo!${SEM_COR}"
  exit 1
fi

# --- FUNÇÕES ---

function veri_openvpn (){
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não instalado. Iniciando instalação...${SEM_COR}"
        DIR_INSTALACAO="/home/jutair/configdebian-main"
        mkdir -p "$DIR_INSTALACAO"
        wget -P "$DIR_INSTALACAO" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
        chmod +x "$DIR_INSTALACAO"/openvpn-install.sh
        cd "$DIR_INSTALACAO" || exit
        sudo ./openvpn-install.sh
    fi

    echo -e "${AMARELO}--- Verificando Integridade do Sistema ---${SEM_COR}"
    if [ -d "/etc/openvpn/easy-rsa" ]; then
        EASYRSA_DIR="/etc/openvpn/easy-rsa"
    elif [ -d "/etc/openvpn/server/easy-rsa" ]; then
        EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    else
        EASYRSA_DIR="/etc/openvpn/easy-rsa"
    fi

    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    SERVER_CONF="/etc/openvpn/server/server.conf"
    CRL_FILE="/etc/openvpn/server/crl.pem"

    if [ ! -f "$INDEX_FILE" ]; then
        sudo mkdir -p "$(dirname "$INDEX_FILE")"
        sudo touch "$INDEX_FILE"
        sudo chmod 644 "$INDEX_FILE"
    fi

    if [ -f "$SERVER_CONF" ] && ! grep -q "crl-verify" "$SERVER_CONF"; then
        if [ ! -f "$CRL_FILE" ]; then
             if [ -f "$EASYRSA_DIR/easyrsa" ]; then
                cd "$EASYRSA_DIR" && sudo ./easyrsa gen-crl
                sudo cp "$EASYRSA_DIR/pki/crl.pem" "$CRL_FILE"
             else
                sudo touch "$CRL_FILE"
             fi
        fi
        echo "crl-verify $CRL_FILE" | sudo tee -a "$SERVER_CONF"
        sudo systemctl restart openvpn-server@server
    fi
    echo -e "${VERDE}[PRONTO] Sistema validado.${SEM_COR}\n"
}

function user_online {
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo "Erro: Arquivo de log não encontrado."
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
}

function user_consumo {
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

    if [ ! -f "$STATUS_FILE" ]; then
        echo "Erro: Arquivo de log não encontrado!"
        return
    fi

    echo "==============================================================="
    echo "             CONSUMO DE DADOS POR UTILIZADOR"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "UTILIZADOR" "RECEBIDO" "ENVIADO" "TOTAL"
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
}

function relatorio_consumo {
    clear
    INTERFACE="tun0"
    while true; do
        echo "======================================"
        echo "   Relatório de consumo de rede:      "
        echo "======================================"
        echo "[1] Anual  [2] Mensal  [3] Diário  [4] Sair"
        read -n 1 -p "Opção: " OPCAO
        echo ""
        case $OPCAO in
            1) vnstat -y -i "$INTERFACE
