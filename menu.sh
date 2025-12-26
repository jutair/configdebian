#!/bin/bash
# menu.sh - Painel de Gestão VPS PRO (Versão Restaurada 2025)

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_SCRIPTS="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
ADMIN_CONF="$DIR_PROT/admin.conf"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- CARREGAR CONFIGURAÇÕES ---
# Tenta ler o administrador cadastrado. Se falhar, o padrão é root.
if [ -f "$ADMIN_CONF" ]; then
    source "$ADMIN_CONF"
else
    ADM_USER="root"
fi
# Garante que ADM_USER não esteja vazio
ADM_USER=${ADM_USER:-"root"}

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
# logname captura o usuário que fez o login inicial (ideal para auditoria)
USER_LOGADO=$(logname 2>/dev/null || whoami)
IP_CONEXAO=$(echo $SSH_CLIENT | awk '{print $1}')
[ -z "$IP_CONEXAO" ] && IP_CONEXAO="Local"
IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")

# --- FUNÇÕES ---

manutencao() {
    clear
    local USUARIO_ATUAL=$(logname 2>/dev/null || whoami)
    local DATA_ATUAL=$(date +'%d/%m/%Y')
    local HORA_ATUAL=$(date +'%H:%M:%S')

    # VALIDAÇÃO: Se for o ADM cadastrado OU se for o root (bypass de segurança)
    if [[ "$USUARIO_ATUAL" == "$ADM_USER" ]] || [[ "$USUARIO_ATUAL" == "root" ]]; then
        echo -e "${VERDE}===============================================================${NC}"
        echo -e "                🛠️  MODO MANUTENÇÃO ATIVADO"
        echo -e "${VERDE}===============================================================${NC}"
        echo -e "Olá ${AMARELO}$USUARIO_ATUAL${NC}, saindo para o terminal direto..."
        
        # Envio de Alerta ao Telegram (Opcional)
        if [ -f "$TELEGRAM_CONF" ]; then
            source "$TELEGRAM_CONF"
            MENSAGEM="🛠️ <b>MANUTENÇÃO:</b>%0AAdmin <code>$USUARIO_ATUAL</code> acessou o shell.%0A<b>IP:</b> <code>$IP_CONEXAO</code>"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi

        sleep 2
        clear
        exec bash # Encerra o menu e entrega o terminal
    else
        # SE NÃO FOR O ADMIN: EXPULSA DO SISTEMA
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "Tentativa de violação pelo usuário: ${AMARELO}$USUARIO_ATUAL${NC}"
        
        if [ -f "$TELEGRAM_CONF" ]; then
            source "$TELEGRAM_CONF"
            MENSAGEM="🚫 <b>ALERTA CRÍTICO:</b>%0AUsr <code>$USUARIO_ATUAL</code> tentou Manutenção!%0A<b>Ação:</b> SSH Encerrado.%0A<b>IP:</b> <code>$IP_CONEXAO</code>%0A<b>Data:</b> $DATA_ATUAL às $HORA_ATUAL"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi

        sleep 3
        pkill -u "$USUARIO_ATUAL" -9 # Derruba a conexão
        exit
    fi
}
dashboard() {
    local CYAN='\033[0;36m'
    local GOLD='\033[1;33m'
    local NC='\033[0m'
    
    # Define as variáveis de identificação se estiverem vazias
    [ -z "$IP_SERVIDOR" ] && IP_SERVIDOR=$(curl -s https://api.ipify.org)
    [ -z "$USER_LOGADO" ] && USER_LOGADO=$(whoami)
    [ -z "$IP_CONEXAO" ] && IP_CONEXAO=$(who am i | awk '{print $NF}' | tr -d '()')

    while true; do
        # --- Coleta de Dados ---
        DATA_ATUAL=$(date +"%d/%m/%Y %H:%M:%S")
        UPTIME=$(uptime -p | sed 's/up //')
        CPU_VAL=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
        CPU_INT=${CPU_VAL%.*}
        MEM_PORC=$(free | awk '/Mem:/{printf("%d", $3/$2*100)}')
        
        # Tráfego
        IFACE_WEB=$(ip route | grep default | awk '{print $5}' | head -n1)
        TRAF_ETH=$(vnstat -i "$IFACE_WEB" --oneline 2>/dev/null | cut -d';' -f11)
        TRAF_TUN=$(vnstat -i "tun0" --oneline 2>/dev/null | cut -d';' -f11)
        [ -z "$TRAF_ETH" ] && TRAF_ETH="0 MB"
        [ -z "$TRAF_TUN" ] && TRAF_TUN="0 MB"

        # Segurança & Usuários
        VPN_ONLINE=$(grep -Ec "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        SSH_ONLINE=$(who | wc -l)
        BANS=$(wc -l < /etc/vps_protecao/bans.log 2>/dev/null || echo "0")
        ATUACAO=$(wc -l < /etc/vps_protecao/guardiao_atua.log 2>/dev/null || echo "0")

        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
        
        # Título e Data (Manaus)
        # Note: Usamos printf sem cores para calcular o espaço e depois imprimimos com cores
        printf "${CYAN}│${NC}  ${GOLD}💎 DASHBOARD VPS PREMIUM${NC} %21s (AMT) ${CYAN}│${NC}\n" "$DATA_ATUAL"
        
        # IP e Logado como (Tratado como string simples para alinhar)
        printf "${CYAN}│${NC}  🌐 IP: %-52s ${CYAN}│${NC}\n" "$IP_SERVIDOR"
        USER_LINE="👤 Logado como: $USER_LOGADO ($IP_CONEXAO)"
        printf "${CYAN}│${NC}  %-55s  ${CYAN}│${NC}\n" "$USER_LINE"
        
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
        
        # Uptime e Hardware
        printf "${CYAN}│${NC}  ⏱️  Uptime: %-46s  ${CYAN}│${NC}\n" "$UPTIME"
        HW_LINE="💻 CPU: $CPU_INT% | 🧠 RAM: $MEM_PORC% | 💾 DISCO: $(df -h / | awk 'NR==2 {print $5}')"
        printf "${CYAN}│${NC}  %-55s  ${CYAN}│${NC}\n" "$HW_LINE"
        
        echo -e "${CYAN}├──────────────┬──────────────────────────────┬───────────────┤${NC}"
        
        # Colunas de Informação (Hardcoded para evitar quebra de tabela)
        echo -e "${CYAN}│${NC}  ${VERDE}📡 TRÁFEGO${NC}  ${CYAN}│${NC}  ${AMARELO}🛡️  SEGURANÇA${NC}            ${CYAN}│${NC}  ${CYAN}👥 ONLINE${NC}   ${CYAN}│${NC}"
        
        # Dados das colunas com espaçamento fixo manual
        printf "${CYAN}│${NC} WEB: %-8s ${CYAN}│${NC} Bans: %-19s ${CYAN}│${NC} VPN: %-7s ${CYAN}│${NC}\n" "$TRAF_ETH" "$BANS" "$VPN_ONLINE"
        printf "${CYAN}│${NC} VPN: %-8s ${CYAN}│${NC} Ações: %-18s ${CYAN}│${NC} SSH: %-7s ${CYAN}│${NC}\n" "$TRAF_TUN" "$ATUACAO" "$SSH_ONLINE"

        echo -e "${CYAN}├──────────────┴──────────────────────────────┴───────────────┤${NC}"
        
        # Sessões SSH
        printf "${CYAN}│${NC}  ${GOLD}🔌 SESSÕES SSH ATIVAS:${NC}                                     ${CY
# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE GESTÃO VPS - DIGITAL OCEAN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  ${AZUL}USUÁRIO:${NC} ${AMARELO}$USER_LOGADO${NC} | ${AZUL}ADMIN:${NC} ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Dashboard em Tempo Real"
    echo -e "  [2] 🌐 Gerenciar OpenVPN"
    echo -e "  [3] 🚀 Rede & Segurança (Firewall/Logs)"
    echo -e "  [4] 👤 Gerenciar Usuários (SSH/Samba)"
    echo -e "  [5] 🆙 Atualizar Sistema / Painel"
    echo -e "  [6] 💾 Backup e Restauração"
    echo -e "  [8] 🛠️  Manutenção (Admin)"
    echo -e "  [0] ❌ Sair"
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
        8) manutencao ;;
        0) exit 0 ;;
        *) echo -e "${VERMELHO}Opção Inválida!${NC}"; sleep 1 ;;
    esac
done
