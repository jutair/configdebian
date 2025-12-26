#!/bin/bash
# gerencia_rede.sh - Central de Comando VPS
# Admin Dinâmico e Segurança Integrada

# --- 1. CONFIGURAÇÕES E AMBIENTE ---
DIR_PROT="/etc/vps_protecao"
ADMIN_CONF="$DIR_PROT/admin.conf"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
ARQUIVO_WHITE="$DIR_PROT/whitelist.conf"
SSH_CONF="/etc/ssh/sshd_config"

# Cores
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Captura Usuário Real
USER_REAL=${SUDO_USER:-${LOGNAME}}
[ "$USER_REAL" == "root" ] && USER_REAL=$(logname 2>/dev/null)
[ -z "$USER_REAL" ] && USER_REAL=$(who am i | awk '{print $1}')

# Carrega Administrador Dinâmico
[ -f "$ADMIN_CONF" ] && source "$ADMIN_CONF" || ADM_USER="admin"

# 🔒 TRAVA DE TERMINAL
trap '' SIGINT SIGTSTP SIGQUIT

# Verifica Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# --- 2. FUNÇÃO DE VALIDAÇÃO ---
verificar_permissao() {
    if [[ "$USER_REAL" != "$ADM_USER" ]]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "Operador: ${AMARELO}$USER_REAL${NC} | Admin Requerido: ${VERDE}$ADM_USER${NC}"
        
        [ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"
        if [[ ! -z "$TOKEN" ]]; then
            MENSAGEM="🚫 <b>ALERTA:</b> Usuário <code>$USER_REAL</code> tentou acessar função restrita."
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3; return 1
    fi
    return 0
}

# --- 3. FUNÇÕES DE PERFORMANCE E REDE ---

testa_velocidade() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Aguarde, testando a conexão da VPS...${NC}"
    
    # Verifica se speedtest-cli está instalado
    if ! command -v speedtest-cli &> /dev/null; then
        echo -e "${VERMELHO}Instalando speedtest-cli...${NC}"
        apt-get install speedtest-cli -y > /dev/null
    fi
    
    speedtest-cli --simple
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

# --- 4. FUNÇÕES DE SEGURANÇA E GESTÃO ---

diagnostico_ataques() {
    clear
    echo -e "${AZUL}--- RANKING DE AGRESSORES (TOP 10) ---${NC}"
    RANKING=$(grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | sort | uniq -c | sort -nr | head -n 10)
    [ -z "$RANKING" ] && echo "Nenhum ataque detectado." || echo "$RANKING"
    read -p "ENTER..." d
}

banir_ip() {
    read -p " IP para BANIR: " IP_ALVO
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        iptables -I INPUT -s "$IP_ALVO" -j DROP
        iptables -I OUTPUT -d "$IP_ALVO" -j DROP
        iptables -I FORWARD -d "$IP_ALVO" -j DROP
        echo -e "${VERDE}IP $IP_ALVO Isolado!${NC}"
    fi
    sleep 2
}

desbanir_ip() {
    read -p " IP para LIBERAR: " IP_D
    iptables -D INPUT -s "$IP_D" -j DROP 2>/dev/null
    iptables -D OUTPUT -d "$IP_D" -j DROP 2>/dev/null
    iptables -D FORWARD -d "$IP_D" -j DROP 2>/dev/null
    echo -e "${VERDE}IP liberado!${NC}"; sleep 2
}

configurar_telegram() {
    verificar_permissao || return
    read -p "Token Bot: " tk; read -p "Chat ID: " cid
    echo -e "TOKEN=\"$tk\"\nID_CHAT=\"$cid\"" > "$TELEGRAM_CONF"
    echo "Salvo!"; sleep 2
}

# --- 5. MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}SISTEMA DE GESTÃO VPS - ADMIN${NC}"
    echo -e "  OPERADOR: ${AMARELO}$USER_REAL${NC} | ADMIN: ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📊 Logs do Sistema         [6] 🚫 Banir IP Malicioso"
    echo -e "  [2] ⚡ Testar Velocidade       [7] ✅ Desbanir IP"
    echo -e "  [3] 🕵️  Diagnóstico de Ataques  [8] 🔑 Config SSH (Admin)"
    echo -e "  [4] 📢 Alertas Telegram        [9] 🔄 Reiniciar Menu"
    echo -e "  [5] 📉 VnStat (Consumo)"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) # Função de Logs (Squid/SSH/Kill)
           visualizar_logs ;; 
        2) testa_velocidade ;;
        3) diagnostico_ataques ;;
        4) configurar_telegram ;;
        5) vnstat -d; read -p "ENTER..." d ;;
        6) banir_ip ;;
        7) desbanir_ip ;;
        8) # Chamar função SSH
           verificar_permissao && echo "Acessando SSH Config..." ;;
        9) continue ;;
        *) sleep 1 ;;
    esac
done
