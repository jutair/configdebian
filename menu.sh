#!/bin/bash
# menu.sh - Painel de Gestão VPS PRO (Versão IP FIX - 24/12/2025)
set -e
DIR_SCRIPTS="/opt/configdebian"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

dashboard() {
    STATUS_LOG=$(grep -r "status " /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    STATUS_LOG=${STATUS_LOG:-"/etc/openvpn/server/openvpn-status.log"}

    while true; do
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
        MEM_USADA=$(free -h | awk '/^Mem:/{print $3}')
        RAM_INFO="$MEM_USADA / $MEM_TOTAL"
        DISCO_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')

        if [ -f "/var/log/ufw.log" ]; then
            BLOQUEIOS=$(grep -c "\[UFW BLOCK\]" /var/log/ufw.log || echo "0")
        else
            BLOQUEIOS=$(dmesg | grep -c "\[UFW BLOCK\]" || echo "0")
        fi

        VPN_ONLINE=$(grep -E "CLIENT_LIST|Common Name" "$STATUS_LOG" 2>/dev/null | grep -v "HEADER" | grep -cv "Common Name" || echo "0")
        SSH_ONLINE=$(who | grep -v "(:0)" | wc -l || echo "0")
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'tun|eth|enp' | head -n1)
        TRAFEGO=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
        [[ -z "$TRAFEGO" || "$TRAFEGO" == *"Error"* ]] && TRAFEGO="Iniciando..."

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                     ${VERDE}DASHBOARD VPS PRO${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Data / Hora" "$DATA | $HORA"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo de CPU" "$CPU"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Memória RAM" "$RAM_INFO"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Espaço em Disco" "$DISCO_INFO"
        printf "  %-25s : ${VERMELHO}%s bloqueios${NC}\n" "Firewall" "$BLOQUEIOS"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários VPN" "$VPN_ONLINE"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários SSH" "$SSH_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Tráfego ($IFACE)" "$TRAFEGO"

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${VERDE}Conexões SSH Ativas${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        who -u | while read -r line; do
            u=$(echo "$line" | awk '{print $1}')
            ip=$(echo "$line" | grep -oP '\(\K[^\)]+')
            printf "👤 %-13s %-20s\n" "$u" "${ip:-Local}"
        done

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${VERDE}Conexões VPN Ativas${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        if [ -f "$STATUS_LOG" ]; then
            grep "," "$STATUS_LOG" | grep -E "CLIENT_LIST|Common Name" | grep -vE "HEADER|ROUTING" | while IFS=',' read -r C1 C2 C3 rest; do
                [[ "$C1" == "CLIENT_LIST" ]] && { UV="$C2"; IV=$(echo "$C3" | cut -d':' -f1); } || { UV="$C1"; IV=$(echo "$C2" | cut -d':' -f1); }
                [[ ! -z "$UV" && "$UV" != "Common Name" ]] && printf "🔐 %-13s %-20s\n" "$UV" "$IV"
            done
        else
            echo -e "${AMARELO}Sem log VPN.${NC}"
        fi
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${AMARELO}Pressione qualquer tecla para sair...${NC}"
        if read -t 5 -n 1; then return; fi
    done
}

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITAL OCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard"
    echo -e "  [2] 🌐 Gerenciar VPN"
    echo -e "  [3] 🚀 Gerenciar Rede"
    echo -e "  [4] 👤 Gerenciar Usuários"
    echo -e "  [5] 🆙 Atualizar Sistema"
    echo -e "  [6] 💾 Backup"
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
        7) clear; exit 0 ;;
        *) echo -e "${VERMELHO}Inválido!${NC}"; sleep 1 ;;
    esac
done
