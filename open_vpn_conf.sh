#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
HOME_USER="/home/$USER_ATUAL"

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

# --- INTEGRAÇÃO DO INSTALADOR (CORREÇÃO DEFINITIVA) ---
# O segredo é rodar o script SEMPRE a partir da pasta onde ele está
if [ -f "$HOME_USER/configdebian-main/openvpn-install.sh" ]; then
    DIRETORIO="$HOME_USER/configdebian-main"
    INSTALADOR="openvpn-install.sh"
elif [ -f "$HOME_USER/openvpn-install.sh" ]; then
    DIRETORIO="$HOME_USER"
    INSTALADOR="openvpn-install.sh"
else
    DIRETORIO="$HOME_USER"
    INSTALADOR="openvpn-install.sh"
    echo -e "${AMARELO}[!] Baixando integrador...${SEM_COR}"
    wget -O "$DIRETORIO/$INSTALADOR" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x "$DIRETORIO/$INSTALADOR"
fi

STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

# --- FUNÇÃO DE GERENCIAMENTO (A CHAVE DA INTEGRAÇÃO) ---
gerenciar_vpn() {
    # Entra no diretório do script para que ele não se perca
    cd "$DIRETORIO" || exit
    # Executa o script de forma limpa e interativa
    sudo ./$INSTALADOR
    
    # Após sair do script do Angristan, sincroniza os certificados
    DESTINO="$HOME_USER/clientes_ovp"
    mkdir -p "$DESTINO"
    # Procura arquivos .ovpn criados no último minuto e move para a pasta do usuário
    find /root /home -maxdepth 2 -name "*.ovpn" -cmin -5 -exec mv {} "$DESTINO/" \; 2>/dev/null
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO"
    echo -e "${VERDE}[OK] Sincronização concluída.${SEM_COR}"
    sleep 2
}

# --- RESTANTE DAS FUNÇÕES (STATUS / CONSUMO) ---

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
        echo "Servidor OpenVPN parece estar offline ou log desativado."
    fi
    read -p "Pressione ENTER..." d
}

user_consumo() {
    clear
    echo "==============================================================="
    echo "               CONSUMO DE DADOS (Sessão Atual)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"
    if [ -f "$STATUS_FILE" ]; then
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
    read -p "Pressione ENTER para voltar..." dummy
}

# --- MENU ---

menu_ovp() {
    while true; do
        clear
        echo "================================================================="
        echo "                      PAINEL OPEN VPN                            "
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
            2) gerenciar_vpn ;;
            3) clear; [ -f "$INDEX_FILE" ] && column -t -s $'\t' "$INDEX_FILE" || echo "PKI não encontrada"; read -p "ENTER..." d ;;
            4) clear; speedtest-cli --source $(ip addr show tun0 | grep "inet " | awk '{print $2}' | cut -d/ -f1) --simple || echo "tun0 offline"; read -p "ENTER..." d ;;
            5) clear; trap '' INT; ( trap - INT; vnstat -l -i tun0 ); trap - INT; read -p "ENTER..." d ;;
            6) user_consumo ;;
            7) exec sudo "$DIRETORIO/menu.sh" ;;
            9) kill -TERM -$(ps -o pgid= -p $$ | grep -o '[0-9]*'); exit 0 ;;
        esac
    done
}

menu_ovp
