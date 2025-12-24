#!/bin/bash
# menu.sh - Painel de Gestão VPS com Dashboard Atualizado
# Atualizado: 24-12-2025

set -e

DIR_SCRIPTS="/opt/configdebian"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

get_ip_servidor() {
    curl -s --max-time 2 ifconfig.me || echo "Desconhecido"
}

get_cpu() {
    awk -v RS="" '{u=$2+$4; t=$2+$4+$5; printf "%.1f%%", u/t*100}' /proc/stat
}

get_traffic() {
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'tun[0-9]+|eth0' | head -n1)
    IFACE=${IFACE:-eth0}
    TRAFFIC=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
    [[ -z "$TRAFFIC" || "$TRAFFIC" == *"No data"* ]] && TRAFFIC="0.00 MB"
    echo "$TRAFFIC ($IFACE)"
}

listar_ssh() {
    w -h | awk '{printf "👤 %-13s %-20s\n", $1, $3}'
}

listar_vpn() {
    if [ -f "$STATUS_LOG" ]; then
        grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ USER IP PORT RECV SENT _ _; do
            IP_REAL=$(echo "$IP" | cut -d':' -f1)
            printf "🔐 %-13s %-20s\n" "$USER" "$IP_REAL"
        done
    else
        echo -e "${AMARELO}Nenhum usuário VPN conectado${NC}"
    fi
}

dashboard() {
    while true; do
        clear
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        IP_SERV=$(get_ip_servidor)
        CPU_USO=$(get_cpu)
        TRAF_VPN=$(get_traffic)
        SSH_ONLINE=$(w -h | wc -l)
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo 0)

        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                     ${VERDE}DASHBOARD VPS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  IP do Servidor            : $IP_SERV"
        echo -e "  Data                      : $DATA"
        echo -e "  Hora (Manaus)             : $HORA"
        echo -e "  Consumo da CPU            : $CPU_USO"
        echo -e "  Usuários VPN Online       : $VPN_ONLINE"
        echo -e "  Usuários SSH Online       : $SSH_ONLINE"
        echo -e "  Tráfego Hoje (eth0/tun)  : $TRAF_VPN"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "Usuários SSH Conectados"
        echo -e "---------------------------------------------------------------"
        listar_ssh
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "Usuários VPN Conectados"
        echo -e "---------------------------------------------------------------"
        listar_vpn
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "Atualizando (5s). Pressione ENTER para MENU..."
        
        # Espera 5 segundos ou ENTER
        read -t 5 -n 1 key
        if [[ -n $key ]]; then
            break
        fi
    done
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITALOCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🖥️  Dashboard VPS"
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
