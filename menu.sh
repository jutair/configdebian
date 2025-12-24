dashboard() {
    while true; do
        clear
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{usage=100-$8} END {printf "%.1f%%", usage}')
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log 2>/dev/null || echo "0")
        SSH_ONLINE=$(who | grep -v "(:0)" | wc -l)
        
        # Detecta interface tun* ou fallback eth0
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep 'tun[0-9]' | head -n1)
        IFACE=${IFACE:-"eth0"}
        TRAFEGO=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
        [[ -z "$TRAFEGO" || "$TRAFEGO" == *"No data"* ]] && TRAFEGO="0.00 MB"

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
            printf "%-15s %-20s\n" "$user" "${ip_real:-Local}"
        done

        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${AMARELO}Atualizando a cada 5 segundos. Pressione Ctrl+C para voltar ao menu principal...${NC}"
        sleep 5
    done
}
