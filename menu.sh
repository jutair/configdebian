#!/bin/bash
# menu.sh - Painel de Gestão VPS (Versão Definitiva 24-12-2025)
set -e

DIR_SCRIPTS="/opt/configdebian"

# Cores
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Captura o IP do servidor uma vez para otimizar
IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

# --- FUNÇÃO DASHBOARD ---
dashboard() {
    STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

    while true; do
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")

        # CPU usage preciso (Debian/Ubuntu)
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')

        # Usuários VPN Online
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        
        # Usuários SSH Online
        SSH_ONLINE=$(who | grep -v "(:0)" | wc -l || echo "0")

        # Detecta interface ativa (VPN ou Ethernet)
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'tun|eth|enp' | head -n1)
        
        # Tráfego com vnstat (Tratamento de erro para base vazia)
        TRAFEGO=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
        if [[ -z "$TRAFEGO" || "$TRAFEGO" == *"Error"* ]]; then
            TRAFEGO="Iniciando..."
        fi

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                     ${VERDE}DASHBOARD VPS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Data" "$DATA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Hora (Manaus)" "$HORA"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo da CPU" "$CPU"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Usuários VPN Online" "$VPN_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Usuários SSH Online" "$SSH_ONLINE"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Tráfego Hoje ($IFACE)" "$TRAFEGO"

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${VERDE}Usuários SSH Conectados${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        who | while read -r user tty date time ip rest; do
            ip_real=$(echo "$ip" | tr -d '()')
            [ -z "$ip_real" ] && ip_real="Local"
            printf "👤 %-13s %-20s\n" "$user" "$ip_real"
        done

        echo -e "${AZUL}---------------------------------------------------------------${NC}"
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
        echo -e "${AMARELO}Atualizando (5s). Pressione qualquer tecla para sair...${NC}"

        # Espera 5 segundos. Se detectar QUALQUER tecla, volta ao menu.
        if read -t 5 -n 1; then
            return
        fi
    done
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITAL OCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard Interativo"
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
