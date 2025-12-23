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

# --- LOCALIZAÇÃO DO INSTALADOR ---
if [ -f "$HOME_USER/configdebian-main/openvpn-install.sh" ]; then
    DIRETORIO="$HOME_USER/configdebian-main"
    INSTALADOR="openvpn-install.sh"
elif [ -f "$HOME_USER/openvpn-install.sh" ]; then
    DIRETORIO="$HOME_USER"
    INSTALADOR="openvpn-install.sh"
else
    DIRETORIO="$HOME_USER"
    INSTALADOR="openvpn-install.sh"
    wget -O "$DIRETORIO/$INSTALADOR" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x "$DIRETORIO/$INSTALADOR"
fi

STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

# --- FUNÇÕES DE APOIO ---

sincronizar_ovpns() {
    DESTINO="$HOME_USER/clientes_ovp"
    mkdir -p "$DESTINO"
    # Move arquivos .ovpn recém-criados para a pasta do usuário
    find /root /home -maxdepth 2 -name "*.ovpn" -cmin -5 -exec mv {} "$DESTINO/" \; 2>/dev/null
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO"
}

# --- INTEGRAÇÃO COM COMANDOS (OPERAÇÕES RÁPIDAS) ---

gerenciar_clientes() {
    while true; do
        clear
        echo "======================================"
        echo "      GERENCIAMENTO DE CLIENTES       "
        echo "======================================"
        echo "[1] Adicionar Cliente (Rápido)"
        echo "[2] Remover Cliente (Rápido)"
        echo "[3] Menu Nativo (Interativo)"
        echo "[4] Voltar"
        echo "======================================"
        read -n 1 -p "Escolha: " M_ACAO
        echo ""

        case $M_ACAO in
            1)
                read -p "Nome do cliente: " CLIENT_NAME
                if [ -n "$CLIENT_NAME" ]; then
                    cd "$DIRETORIO" || exit
                    # Integração via variáveis de ambiente para o Angristan
                    MENU_OPTION="1" CLIENT="$CLIENT_NAME" PASS="1" sudo -E ./$INSTALADOR
                    sincronizar_ovpns
                    read -p "Cliente criado! ENTER..." d
                fi
                ;;
            2)
                read -p "Nome do cliente a remover: " CLIENT_NAME
                if [ -n "$CLIENT_NAME" ]; then
                    cd "$DIRETORIO" || exit
                    MENU_OPTION="2" CLIENT="$CLIENT_NAME" sudo -E ./$INSTALADOR
                    read -p "Cliente removido! ENTER..." d
                fi
                ;;
            3)
                cd "$DIRETORIO" || exit
                sudo ./$INSTALADOR
                sincronizar_ovpns
                ;;
            4) break ;;
        esac
    done
}

# --- CONSUMO E STATUS ---

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
    fi
    read -p "Pressione ENTER..." d
}

user_consumo() {
    clear
    echo "==============================================================="
    echo "               CONSUMO DE DADOS (MB)"
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

# --- MENU PRINCIPAL VPN ---

menu_ovp() {
    while true; do
        clear
        echo "================================================================="
        echo "                      PAINEL OPEN VPN                            "
        echo "================================================================="
        echo "[1] Usuários Online            [5] Monitorar Tráfego (Live)"
        echo "[2] Gerenciar Clientes (Rápido)[6] Relatório de Consumo (MB)"
        echo "[3] Lista Completa (PKI)       [7] Voltar ao Menu Principal"
        echo "[4] Testar Velocidade tun0     [9] Sair do Sistema"
        echo "================================================================="
        read -n 1 -p "Opção: " OPCAO
        echo ""

        case $OPCAO in
            1) user_online ;;
            2) gerenciar_clientes ;;
            3) clear; [ -f "$INDEX_FILE" ] && column -t -s $'\t' "$INDEX_FILE" || echo "PKI não encontrada"; read -p "ENTER..." d ;;
            4) clear; speedtest-cli --source $(ip addr show tun0 | grep "inet " | awk '{print $2}' | cut -d/ -f1) --simple || echo "tun0 offline"; read -p "ENTER..." d ;;
            5) clear; trap '' INT; ( trap - INT; vnstat -l -i tun0 ); trap - INT; read -p "ENTER..." d ;;
            6) user_consumo ;;
            7) exec sudo "$DIRETORIO/menu.sh" ;;
            9) kill -TERM -$(ps -o pgid= -p $$ | grep -o '[0-9]*'); exit 0 ;;
            *) echo "Inválido"; sleep 1 ;;
        esac
    done
}

# Iniciar
sincronizar_ovpns
menu_ovp
