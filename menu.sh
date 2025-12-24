# ------------------- FUNÇÃO DASHBOARD -------------------
dashboard() {
    clear
    echo -e "${AMARELO}Carregando Dashboard... (Pressione qualquer tecla para sair)${NC}"
    
    while true; do
        # 1. Coleta de Dados
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        
        # Cálculo de CPU Corrigido para Debian
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log 2>/dev/null || echo "0")
        SSH_ONLINE=$(who | wc -l)
        
        # Interface de Rede
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'tun|eth|enp' | head -n1)
        TRAFEGO=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6 || echo "Calculando...")

        # 2. Interface Visual
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                     ${VERDE}DASHBOARD VPS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Data" "$DATA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Hora (Manaus)" "$HORA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo da CPU" "$CPU"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "VPN Online" "$VPN_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "SSH Online" "$SSH_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Tráfego Hoje ($IFACE)" "$TRAFEGO"

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${VERDE}Usuários SSH Conectados${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "%-15s %-20s\n" "USUÁRIO" "IP ORIGEM"
        who | awk '{print $1, $5}' | tr -d '()' | while read -r user ip; do
            printf "%-15s %-20s\n" "$user" "${ip:-Local}"
        done

        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${AMARELO}Atualizando a cada 5s. Pressione qualquer tecla para MENU...${NC}"

        # 3. Controle de Saída (Aguardar 5 segundos ou tecla)
        read -t 5 -n 1 && break
    done
}
