#!/bin/bash
# menu.sh - Painel de Gestão VPS (Resiliente e Auto-configurável)

DIR_SCRIPTS="$HOME/configdebian-main"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Coleta o IP Externo uma vez (timeout de 2s)
IP_EXT=$(curl -s --max-time 2 ifconfig.me || echo "Erro ao obter IP")

while true; do
    # --- DADOS DINÂMICOS ---
    USER_SSH=$(who | wc -l)
    MEM_LIVRE=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
    DISCO=$(df -h / | awk '/\// { print $5 }')
    UPTIME=$(uptime -p | sed 's/up //')
    
    # --- LÓGICA DE BANDA INTELIGENTE ---
    IFACE="eth0"
    if ip link show tun0 > /dev/null 2>&1; then
        # Se tun0 existe mas não está no vnstat, adiciona-a
        if ! vnstat --dbiflist | grep -q "tun0"; then
            sudo vnstat -i tun0 --add > /dev/null 2>&1
            systemctl restart vnstat > /dev/null 2>&1
        fi
        
        BANDA_HOJE=$(vnstat -i tun0 --oneline 2>/dev/null | cut -d';' -f6)
        
        # Se a tun0 ainda estiver vazia no banco, usa eth0 como fallback
        if [ -z "$BANDA_HOJE" ] || [[ "$BANDA_HOJE" == *"Error"* ]] || [[ "$BANDA_HOJE" == "0.00 MB" ]]; then
            BANDA_HOJE=$(vnstat -i eth0 --oneline 2>/dev/null | cut -d';' -f6)
            IFACE="eth0"
        else
            IFACE="tun0"
        fi
    else
        BANDA_HOJE=$(vnstat -i eth0 --oneline 2>/dev/null | cut -d';' -f6)
        IFACE="eth0"
    fi

    [ -z "$BANDA_HOJE" ] && BANDA_HOJE="Calculando..."

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITALOCE${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  %-15s : %-20s\n" "IP EXTERNO" "${AMARELO}$IP_EXT${NC}"
    printf "  %-15s : %-20s\n" "SSH ATIVOS" "${AMARELO}$USER_SSH${NC}"
    printf "  %-15s : %-20s\n" "BANDA (HOJE)" "${VERDE}$BANDA_HOJE ($IFACE)${NC}"
    printf "  %-15s : %-20s\n" "MEMÓRIA RAM" "${AMARELO}$MEM_LIVRE em uso${NC}"
    printf "  %-15s : %-20s\n" "DISCO (/)  " "${AMARELO}$DISCO ocupado${NC}"
    printf "  %-15s : %-20s\n" "UPTIME     " "${AMARELO}$UPTIME${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "  [2] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "  [3] 👤 Gerenciar Usuários do Sistema"
    echo -e "  [4] 🆙 Atualizar Sistema"
    echo -e "  [5] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ] && sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        2) [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ] && sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        3) [ -f "$DIR_SCRIPTS/usuarios.sh" ] && sudo -E bash "$DIR_SCRIPTS/usuarios.sh" ;;
        4) [ -f "$DIR_SCRIPTS/update_sistema.sh" ] && sudo -E bash "$DIR_SCRIPTS/update_sistema.sh" ;;
        5) clear; echo -e "${VERDE}Sessão finalizada.${NC}"; exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
