#!/bin/bash
# menu.sh - Painel de Gestão VPS (Versão Integrada Final)

# --- DEFINIÇÃO DO DIRETÓRIO (Deve bater com o setup_vps.sh) ---
DIR_SCRIPTS="$HOME/configdebian-main"

# --- CORES ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Coleta o IP Externo uma vez para economizar recursos
IP_EXT=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

while true; do
    # --- DADOS DINÂMICOS DO DASHBOARD ---
    USUARIO_NOME=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
    IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
    [ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local/Terminal"

    USER_SSH=$(who | wc -l)
    
    # Cálculo de CPU Preciso
    CPU_USO=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
    MEM_LIVRE=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
    DISCO=$(df -h / | awk '/\// { print $5 }')
    UPTIME=$(uptime -p | sed 's/up //')
    
    # Lógica de Banda Inteligente
    IFACE=$(ip route | grep default | awk '{print $5}')
    BANDA_HOJE=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
    [[ -z "$BANDA_HOJE" ]] || [[ "$BANDA_HOJE" == *"No data"* ]] && BANDA_HOJE="0.00 MB"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITALOCE${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "IP SERVIDOR" "$IP_EXT"
    printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "LOGADO COMO" "$USUARIO_NOME ($IP_CONEXAO)"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "SSH ATIVOS" "$USER_SSH"
    printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "BANDA (HOJE)" "$BANDA_HOJE ($IFACE)"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "USO DA CPU" "$CPU_USO"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "MEMÓRIA RAM" "$MEM_LIVRE em uso"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "DISCO (/)" "$DISCO ocupado"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "UPTIME" "$UPTIME"
    
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "  [2] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "  [3] 👤 Gerenciar Usuários do Sistema"
    echo -e "  [4] 📦 Backup e Restauração"
    echo -e "  [5] 🆙 Atualizar Sistema"
    echo -e "  [6] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ] && sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        2) [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ] && sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        3) [ -f "$DIR_SCRIPTS/usuarios.sh" ] && sudo -E bash "$DIR_SCRIPTS/usuarios.sh" ;;
        4) [ -f "$DIR_SCRIPTS/backup.sh" ] && sudo -E bash "$DIR_SCRIPTS/backup.sh" ;;
        5) [ -f "$DIR_SCRIPTS/update_sistema.sh" ] && sudo -E bash "$DIR_SCRIPTS/update_sistema.sh" ;;
        6) clear; echo -e "${VERDE}Sessão finalizada.${NC}"; exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
