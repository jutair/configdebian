#!/bin/bash
# menu.sh - Painel de Gestão VPS PRO (Versão Restaurada 2025)

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_SCRIPTS="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este painel requer privilégios de ROOT.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

# --- 1. DETECÇÃO DO USUÁRIO E CONEXÃO ---
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_LOGADO=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_LOGADO=$(whoami)
fi

IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
[ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local"
IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

# --- FUNÇÕES ---
dashboard() {
    # Localiza o arquivo de log do OpenVPN dinamicamente
    STATUS_LOG=$(grep -r "status " /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    STATUS_LOG=${STATUS_LOG:-"/etc/openvpn/server/openvpn-status.log"}

    while true; do
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f%%", 100 - $1}')
        MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
        MEM_USADA=$(free -h | awk '/^Mem:/{print $3}')
        DISCO_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')

        VPN_ONLINE=$(grep -E "CLIENT_LIST|Common Name" "$STATUS_LOG" 2>/dev/null | grep -v "HEADER" | grep -cv "Common Name" || echo "0")
        SSH_ONLINE=$(who | wc -l || echo "0")

        # Lógica de Tráfego Mensal (ETH0/VNSTAT)
        IFACE_WEB=$(ip route | grep default | awk '{print $5}' | head -n1)
        if command -v vnstat &>/dev/null; then
            TRAFEGO_MES=$(vnstat -i "$IFACE_WEB" --oneline 2>/dev/null | cut -d';' -f11)
        else
            TRAFEGO_MES="VnStat não instalado"
        fi
        [ -z "$TRAFEGO_MES" ] && TRAFEGO_MES="Coletando..."

        # Lógica de Tráfego VPN Ativo
        if [ -f "$STATUS_LOG" ]; then
            BYTES_VPN=$(grep "CLIENT_LIST" "$STATUS_LOG" | awk -F',' '{sum += $5 + $6} END {printf "%.2f", sum/1024/1024/1024}')
            TRAFEGO_VPN="${BYTES_VPN} GB"
        else
            TRAFEGO_VPN="0.00 GB"
        fi

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                    ${VERDE}DASHBOARD VPS PRO${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Logado como" "$USER_LOGADO ($IP_CONEXAO)"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo de CPU" "$CPU"
        printf "  %-25s : ${AMARELO}%s / %s${NC}\n" "Memória RAM" "$MEM_USADA" "$MEM_TOTAL"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Espaço em Disco" "$DISCO_INFO"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários VPN" "$VPN_ONLINE"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários SSH" "$SSH_ONLINE"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Mensal Total ($IFACE_WEB)" "$TRAFEGO_MES"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo VPN Ativo" "$TRAFEGO_VPN"
        echo -e "${AZUL}===============================================================${NC}"
        
        echo -e "${VERDE}Conexões SSH Ativas:${NC}"
        who -u | awk '{print "👤 " $1 "  " $NF}' | sed 's/(//g; s/)//g'
        
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${AMARELO}Pressione 'M' para voltar ao Menu...${NC}"
        read -t 5 -n 1 INPUT
        if [[ $INPUT == "m" || $INPUT == "M" ]]; then return; fi
    done
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITAL OCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  ${AZUL}USUÁRIO:${NC} ${AMARELO}$USER_LOGADO${NC} | ${AZUL}IP:${NC} ${AMARELO}$IP_CONEXAO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard em Tempo Real"
    echo -e "  [2] 🌐 Gerenciar OpenVPN"
    echo -e "  [3] 🚀 Rede & Segurança (Firewall/Logs)"
    echo -e "  [4] 👤 Gerenciar Usuários (SSH/Samba)"
    echo -e "  [5] 🆙 Atualizar Sistema / Painel"
    echo -e "  [6] 💾 Backup e Restauração"
    echo -e "  [7] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OPCAO
    echo ""

    case $OPCAO in
        1) dashboard ;;
        2) [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ] && bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        3) [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ] && bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        4) [ -f "$DIR_SCRIPTS/usuarios.sh" ] && bash "$DIR_SCRIPTS/usuarios.sh" ;;
        5) [ -f "$DIR_SCRIPTS/update_sistema.sh" ] && bash "$DIR_SCRIPTS/update_sistema.sh" ;;
        6) [ -f "$DIR_SCRIPTS/backup.sh" ] && bash "$DIR_SCRIPTS/backup.sh" ;;
        7) exit 0 ;;
        *) echo -e "${VERMELHO}Opção Inválida!${NC}"; sleep 1 ;;
    esac
done
