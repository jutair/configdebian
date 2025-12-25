#!/bin/bash
# menu.sh - Painel de Gestão VPS PRO (Versão IP FIX - 24/12/2025)

# --- REMOVIDO O 'set -e' PARA EVITAR FECHAMENTO INESPERADO ---
DIR_SCRIPTS="/opt/configdebian"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- 1. DETECÇÃO DO USUÁRIO E CONEXÃO ---
# Detecta o usuário real via Kernel (mesma técnica que funcionou antes)
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_LOGADO=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_LOGADO=$(whoami)
fi

# Detecta o IP de onde o usuário está conectado
IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
[ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local"

# Verifica se o usuário tem poderes de root (UID 0 ou grupo sudo)
if [ "$EUID" -eq 0 ]; then
    PODERES="${VERDE}ROOT (Total)${NC}"
else
    PODERES="${AMARELO}Usuário Comum${NC}"
fi

IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

# --- FUNÇÕES ---
dashboard() {
    # Localizador de Log
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

        VPN_ONLINE=$(grep -E "CLIENT_LIST|Common Name" "$STATUS_LOG" 2>/dev/null | grep -v "HEADER" | grep -cv "Common Name" || echo "0")
        SSH_ONLINE=$(who | wc -l || echo "0")

        # --- LÓGICA DE TRÁFEGO MENSAL (ETH0) ---
        IFACE_WEB=$(ip route | grep default | awk '{print $5}' | head -n1)
        # Campo 11 do vnstat --oneline é o total do mês atual (TX + RX)
        TRAFEGO_MES=$(vnstat -i "$IFACE_WEB" --oneline 2>/dev/null | cut -d';' -f11)
        [ -z "$TRAFEGO_MES" ] && TRAFEGO_MES="Coletando dados..."

        # --- LÓGICA DE TRÁFEGO DA SESSÃO VPN (TUN0) ---
        # Somatória do que os clientes ativos estão consumindo agora
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
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Memória RAM" "$RAM_INFO"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Espaço em Disco" "$DISCO_INFO"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários VPN" "$VPN_ONLINE"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários SSH" "$SSH_ONLINE"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Mensal Total ($IFACE_WEB)" "$TRAFEGO_MES"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Consumo VPN Ativo" "$TRAFEGO_VPN"
        echo -e "${AZUL}===============================================================${NC}"
        
        echo -e "${VERDE}Conexões SSH Ativas${NC}"
        who -u | awk '{print "👤 " $1 "  " $NF}' | sed 's/(//g; s/)//g'
        
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${AMARELO}Pressione qualquer tecla para sair...${NC}"
        if read -t 5 -n 1; then return; fi
    done
}
# --- MENU PRINCIPAL ---

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITAL OCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  ${AZUL}USUÁRIO:${NC} ${AMARELO}$USER_LOGADO${NC} | ${AZUL}IP:${NC} ${AMARELO}$IP_CONEXAO${NC}"
    echo -e "  ${AZUL}PERMISSÃO:${NC} $PODERES"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard"
    echo -e "  [2] 🌐 Gerenciar VPN"
    echo -e "  [3] 🚀 Gerenciar Rede & Segurança"
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
