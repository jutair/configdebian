#!/bin/bash
# menu.sh - Painel de Gestão VPS com Dashboard (Atualizado 24-12-2025)

set -e

DIR_SCRIPTS="/opt/configdebian"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

# Função de dashboard
dashboard() {
    while true; do
        clear
        DATA=$(date +"%Y-%m-%d")
        HORA=$(TZ="America/Manaus" date +"%H:%M:%S")
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{usage=100-$8} END {printf "%.1f%%", usage}')
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log 2>/dev/null || echo "0")
        SSH_ONLINE=$(who | grep -v "(:0)" | wc -l)
        TRAFEGO=$(vnstat -i tun0 --oneline 2>/dev/null | cut -d';' -f6)
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
            printf "%-15s %-20s\n" "$user" "$ip_real"
        done

        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${AMARELO}Atualizando a cada 60 segundos. Pressione Ctrl+C para voltar ao menu principal...${NC}"
        sleep 60
    done
}

# Função do menu principal
menu_principal() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DASHBOARD${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 📊 Abrir Dashboard em tempo real"
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
}

menu_principal
