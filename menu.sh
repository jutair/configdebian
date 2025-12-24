#!/bin/bash
# menu.sh - Painel de Gestão VPS (Atualizado 24-12-2025)

set -e

DIR_SCRIPTS="/opt/configdebian"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# IP do servidor
IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

dashboard() {
    STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                     ${VERDE}DASHBOARD VPS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Atualizando a cada 5 segundos. Pressione ENTER para voltar ao menu principal...${NC}"

    # Desabilita echo para capturar ENTER
    stty -echo -icanon time 0 min 0

    while true; do
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{usage=100-$8} END {printf "%.1f%%", usage}')
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        SSH_ONLINE=$(who | grep -v "(:0)" | wc -l)

        # Detecta interface tun*, fallback eth0
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep 'tun[0-9]' | head -n1)
        IFACE=${IFACE:-"eth0"}
        TRAFEGO=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6 || echo "0.00 MB")

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                     ${VERDE}DASHBOARD VPS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Data" "$DATA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Hora do Sistema (Manaus)" "$HORA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo da CPU" "$CPU"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Usuários VPN Online" "$VPN_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Usuários SSH Online" "$SSH_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Tráfego VPN Hoje" "$TRAFEGO"

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${VERDE}Usuários SSH Conectados (IP real)${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "%-15s %-20s\n" "USUÁRIO" "IP ORIGEM"
        who | while read -r user tty date time ip rest; do
            ip_real=$(echo "$ip" | tr -d '()')
            [ -z "$ip_real" ] && ip_real="Local"
            printf "👤 %-13s %-20s\n" "$user" "$ip_real"
        done

        echo -e "${VERDE}Usuários VPN Conectados${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        if [ -f "$STATUS_LOG" ]; then
            grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ USER IP PORT RECV SENT _ _; do
                IP_REAL=$(echo "$IP" | cut -d':' -f1)
                printf "🔐 %-13s %-20s\n" "$USER" "$IP_REAL"
            done
        else
            echo -e "${AMARELO}Nenhum usuário VPN conectado${NC}"
        fi

        echo -e "${AZUL}===============================================================${NC}"

        # --- Verifica se ENTER foi pressionado ---
        read -t 5 -n 1 KEY
        if [[ "$KEY" == $'\n' ]]; then
            break
        fi
    done

    # Restaura o terminal
    stty sane
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                      ${VERDE}MENU PRINCIPAL${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard"
    echo -e "  [2] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "  [3] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "  [4] 👤 Gerenciar Usuários do Sistema"
    echo -e "  [5] 🆙 Atualizar Sistema"
    echo -e "  [6] 💾 Backup do Sistema"
    echo -e "  [7] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) dashboard ;;
        2) sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        3) sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        4) sudo -E bash "$DIR_SCRIPTS/usuarios.sh" ;;
        5) sudo -E bash "$DIR_SCRIPTS/update_sistema.sh" ;;
        6) sudo -E bash "$DIR_SCRIPTS/backup.sh" ;;
        7) clear; echo -e "${VERDE}Sessão finalizada.${NC}"; exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
