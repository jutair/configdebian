#!/bin/bash
# menu.sh - Painel de Gestão VPS PRO (Versão Blindada - 26/12/2025)

# --- CONFIGURAÇÕES DE DIRETÓRIOS ---
DIR_SCRIPTS="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"

# --- CORES ---
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- 1. CARREGA IDENTIDADE DO ADMINISTRADOR ---
if [ -f "$DIR_PROT/config.conf" ]; then
    source "$DIR_PROT/config.conf"
else
    ADM_USER="root" # Fallback caso o instalador não tenha rodado
fi

# --- 2. DETECÇÃO DO USUÁRIO REAL ---
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_LOGADO=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_LOGADO=$(whoami)
fi

# --- 3. BLOQUEIO DE INTERRUPÇÃO (CTRL+C, CTRL+Z, CTRL+\) ---
fechar_sessao_aborto() {
    if [ "$USER_LOGADO" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ ACESSO NEGADO! Encerrando sessão por segurança...${NC}"
        sleep 1
        pkill -u "$USER_LOGADO" -9
        exit 1
    fi
}
# Captura interrupções e força o fechamento para o operador
trap fechar_sessao_aborto SIGINT SIGTSTP SIGQUIT

# --- 4. DETECÇÃO DE CONEXÃO ---
IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
[ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local"
IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

if [ "$USER_LOGADO" == "$ADM_USER" ]; then
    PODERES="${VERDE}ADMINISTRADOR (Acesso ao Shell Liberado)${NC}"
else
    PODERES="${AMARELO}OPERADOR (Acesso Restrito ao Menu)${NC}"
fi

# --- FUNÇÕES ---
dashboard() {
    STATUS_LOG=$(grep -r "status " /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    STATUS_LOG=${STATUS_LOG:-"/etc/openvpn/server/openvpn-status.log"}

    while true; do
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        RAM_INFO=$(free -h | awk '/^Mem:/{print $3 " / " $2}')
        DISCO_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
        VPN_ONLINE=$(grep -E "CLIENT_LIST|Common Name" "$STATUS_LOG" 2>/dev/null | grep -v "HEADER" | grep -cv "Common Name" || echo "0")
        SSH_ONLINE=$(who | wc -l || echo "0")
        IFACE_WEB=$(ip route | grep default | awk '{print $5}' | head -n1)
        TRAFEGO_MES=$(vnstat -i "$IFACE_WEB" --oneline 2>/dev/null | cut -d';' -f11)

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
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Mensal ($IFACE_WEB)" "${TRAFEGO_MES:-Coletando...}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${VERDE}Conexões SSH Ativas${NC}"
        who -u | awk '{print "👤 " $1 "  " $NF}' | sed 's/(//g; s/)//g'
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e "${AMARELO}Pressione qualquer tecla para voltar ao menu...${NC}"
        if read -t 10 -n 1; then return; fi
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
    
    # Restrição Visual e Funcional
    if [ "$USER_LOGADO" == "$ADM_USER" ]; then
        echo -e "  [5] 🆙 Atualizar Sistema"
        echo -e "  [6] 💾 Backup"
    fi

    echo -e "  [7] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) dashboard ;;
        2) sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        3) sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        4) sudo -E bash "$DIR_SCRIPTS/usuarios.sh" ;;
        5) 
            if [ "$USER_LOGADO" == "$ADM_USER" ]; then
                sudo -E bash "$DIR_SCRIPTS/update_sistema.sh"
            else
                echo -e "${VERMELHO}❌ Acesso Negado!${NC}"; sleep 1
            fi
            ;;
        6) 
            if [ "$USER_LOGADO" == "$ADM_USER" ]; then
                sudo -E bash "$DIR_SCRIPTS/backup.sh"
            else
                echo -e "${VERMELHO}❌ Acesso Negado!${NC}"; sleep 1
            fi
            ;;
        7) 
            if [ "$USER_LOGADO" == "$ADM_USER" ]; then
                echo -e "${AMARELO}Saindo para o terminal...${NC}"
                clear; exit 0
            else
                echo -e "${VERMELHO}Encerrando sessão SSH...${NC}"
                sleep 1
                pkill -u "$USER_LOGADO" -9
                exit 0
            fi
            ;;
        *) echo -e "${VERMELHO}Opção Inválida!${NC}"; sleep 1 ;;
    esac
done
