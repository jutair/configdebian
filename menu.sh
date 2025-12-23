#!/bin/bash
# menu.sh - Painel de Gestão VPS (Monitoramento Completo + IP de Conexão)

DIR_SCRIPTS="$HOME/configdebian-main"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Coleta o IP Externo do SERVIDOR uma vez na abertura
IP_EXT=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

while true; do
    # --- DADOS DINÂMICOS ---
    USUARIO_NOME=$(whoami)
    # Extrai o IP de quem está acessando o SSH (IP do seu PC)
    IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
    [ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local/Terminal"

    USER_SSH=$(who | wc -l)
    
    # Cálculo de CPU
    CPU_USO=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    
    MEM_LIVRE=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
    DISCO=$(df -h / | awk '/\// { print $5 }')
    UPTIME=$(uptime -p | sed 's/up //')
    
    # --- LÓGICA DE BANDA ---
    IFACE="eth0"
    if ip link show tun0 > /dev/null 2>&1; then
        IFACE="tun0"
        BANDA_HOJE=$(vnstat -i tun0 --oneline 2>/dev/null | cut -d';' -f6)
    else
        BANDA_HOJE=$(vnstat -i eth0 --oneline 2>/dev/null | cut -d';' -f6)
    fi

    if [[ -z "$BANDA_HOJE" ]] || [[ "$BANDA_HOJE" == *"Error"* ]] || [[ "$BANDA_HOJE" == *"No data"* ]]; then
        BANDA_HOJE="0.00 MB"
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}"PAINEL DE GESTÃO VPS - $USUARIO_NOME"${NC}"
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
