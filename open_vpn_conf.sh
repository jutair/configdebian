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
            1) vnstat -y -i "$INTERFACE" ;;
            2) vnstat -m -i "$INTERFACE" ;;
            3) vnstat -d -i "$INTERFACE" ;;
            4) break ;;
        esac
    done
}

function velocidade_tun0 {
    clear
    IP_TUN0=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    if [ -z "$IP_TUN0" ]; then
        echo "❌ Erro: Interface tun0 offline."
        return
    fi
    echo "================================================================="
    echo "           TESTE DE VELOCIDADE - IP: $IP_TUN0"
    echo "================================================================="
    speedtest-cli --source "$IP_TUN0" --simple
    echo "================================================================="
}

function tun0_monitor {
    clear
    echo "Monitorando interface tun0... (Ctrl+C para parar)"
    vnstat -l -i tun0
}

function menu_ovp {
    while true; do
        echo "================================================================="
        echo "                         Menu Open VPN:                          "
        echo "================================================================="
        echo "[1] Testar velocidade      [5] Monitorar tun0"
        echo "[2] Usuários online        [6] Gerenciar usuário (Adicionar/Remover)"
        echo "[3] Relatório de consumo   [7] Sair"
        echo "[4] Consumo por usuário"
        echo "================================================================="
        read -n 1 -p "Digite a opção: " OPCAO
        echo ""
        case $OPCAO in
            1) velocidade_tun0 ;;
            2) user_online ;;
            3) relatorio_consumo ;;
            4) user_consumo ;;
            5) tun0_monitor ;;
            6) 
                # Verifica se o script existe no local esperado ou no diretório atual
                IF_PATH="/home/jutair/configdebian-main/openvpn-install.sh"
                if [ -f "$IF_PATH" ]; then
                    sudo "$IF_PATH" interactive
                elif [ -f "./openvpn-install.sh" ]; then
                    sudo ./openvpn-install.sh interactive
                else
                    echo -e "${VERMELHO}Erro: Script openvpn-install.sh não encontrado!${SEM_COR}"
                    sleep 2
                fi
                ;;
            7) exit 0 ;;
            *) clear; echo -e "${VERMELHO}Opção inválida!${SEM_COR}" ;;
        esac
    done
}

# --- INÍCIO DO SCRIPT ---
clear
veri_openvpn  # Primeiro valida o sistema
menu_ovp      # Depois chama o menu principal
