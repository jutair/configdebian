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
    # Localiza o arquivo de log do OpenVPN dinamicamente
    STATUS_LOG=$(grep -r "status " /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    STATUS_LOG=${STATUS_LOG:-"/etc/openvpn/server/openvpn-status.log"}
    
    # Caminhos para logs de atuação
    LOG_BANS="/etc/vps_protecao/bans.log"
    LOG_GUARDIAO="/etc/vps_protecao/guardiao_atua.log"

    while true; do
        # --- Configuração de Data e Hora (Manaus) ---
        # TZ=America/Manaus força o comando date a usar o fuso -4
        DATA_MANAUS=$(TZ="America/Manaus" date +"%d/%m/%Y %H:%M:%S")

        # --- Coleta de Hardware ---
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f%%", 100 - $1}')
        MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
        MEM_USADA=$(free -h | awk '/^Mem:/{print $3}')
        DISCO_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')

        # --- Coleta de Usuários ---
        VPN_ONLINE=$(grep -E "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null | grep -v "HEADER" | wc -l || echo "0")
        SSH_ONLINE=$(who | wc -l || echo "0")

        # --- Coleta de Segurança (Firewall e Guardião) ---
        TOTAL_BANS=$( [ -f "$LOG_BANS" ] && wc -l < "$LOG_BANS" || echo "0" )
        ATUA_GUARDIAO=$( [ -f "$LOG_GUARDIAO" ] && wc -l < "$LOG_GUARDIAO" || echo "0" )

        # --- Lógica de Tráfego Mensal ---
        IFACE_WEB=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        get_traff() {
            local iface=$1
            if command -v vnstat &>/dev/null; then
                # Pega tráfego do mês atual (TX+RX formatado)
                vnstat -i "$iface" --oneline | cut -d';' -f11 2>/dev/null || echo "0 MB"
            else
                echo "N/A"
            fi
        }

        TRAF_MES_ETH=$(get_traff "$IFACE_WEB")
        TRAF_MES_TUN=$(get_traff "tun0")

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                    ${VERDE}DASHBOARD VPS PRO${NC}"
        echo -e "             ${AMARELO}Manaus (AMT): $DATA_MANAUS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "IP do Servidor" "$IP_SERVIDOR"
        printf "  %-25s : ${AMARELO}%s${NC}\n" "Logado como" "$USER_LOGADO ($IP_CONEXAO)"
        echo -e "${AZUL}----------------------- RECURSOS ------------------------------${NC}"
        printf "  %-25s : ${AMARELO}%-10s${NC} | DISCO: ${AMARELO}%s${NC}\n" "CPU" "$CPU" "$DISCO_INFO"
        printf "  %-25s : ${AMARELO}%s / %s${NC}\n" "Memória RAM" "$MEM_USADA" "$MEM_TOTAL"
        echo -e "${AZUL}----------------------- TRÁFEGO MENSAL ------------------------${NC}"
        printf "  %-25s : ${VERDE}%-10s${NC} | TUN0: ${VERDE}%s${NC}\n" "Interface ($IFACE_WEB)" "$TRAF_MES_ETH" "$TRAF_MES_TUN"
        echo -e "${AZUL}----------------------- SEGURANÇA -----------------------------${NC}"
        printf "  %-25s : ${VERMELHO}%s bans${NC}\n" "Firewall (Bloqueios)" "$TOTAL_BANS"
        printf "  %-25s : ${AMARELO}%s atuações${NC}\n" "Guardião (Defesas)" "$ATUA_GUARDIAO"
        echo -e "${AZUL}----------------------- CONEXÕES ------------------------------${NC}"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários VPN" "$VPN_ONLINE"
        printf "  %-25s : ${VERDE}%s online${NC}\n" "Usuários SSH" "$SSH_ONLINE"
        
        echo -e "\n${VERDE}Conexões SSH Ativas:${NC}"
        who -u | awk '{print " 👤 " $1 "  " $NF}' | sed 's/(//g; s/)//g' | head -n 3
        
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "${AMARELO}Pressione 'M' para voltar ao Menu... (Atualizando 5s)${NC}"
        
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
