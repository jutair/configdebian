#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional (Integrado)

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_PROT="/etc/vps_protecao"
SSH_CONF="/etc/ssh/sshd_config"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este módulo requer privilégios elevados para gerenciar Firewall/SSH.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

# 1. IDENTIFICAÇÃO DO ADMINISTRADOR E USUÁRIO REAL
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_REAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_REAL=$(whoami)
fi

# Bloqueia CTRL+C para evitar queda no terminal
trap '' SIGINT

# --- FUNÇÕES DE REDE E PERFORMANCE ---

testa_velocidade() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    if ! command -v speedtest-cli &> /dev/null; then
        echo -e "${AMARELO}Instalando speedtest-cli...${NC}"
        apt-get install speedtest-cli -y > /dev/null
    fi
    speedtest-cli --simple
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitora_placa() {
    clear
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    if ! command -v vnstat &> /dev/null; then apt-get install vnstat -y > /dev/null; fi
    echo -e "${AMARELO}Monitorando interface: $INTERFACE (Pressione CTRL+C para sair)${NC}"
    # vnstat -l abre um subshell, então o trap precisa ser temporariamente liberado
    trap - SIGINT
    vnstat -l -i "$INTERFACE"
    trap '' SIGINT
}

# --- FUNÇÕES DE SEGURANÇA E FIREWALL ---

visualizar_logs() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${AMARELO}📊 MONITOR DE LOGS DO SISTEMA${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🔐 Log de Autenticação (SSH/Falhas)"
        echo -e "  [2] 🛡️  Log do Guardião (Segurança)"
        echo -e "  [3] 🧹 Limpar Histórico de Logs"
        echo -e "  [4] ⬅️  Voltar"
        read -n 1 -p " Escolha: " OP_LOG; echo ""
        case $OP_LOG in
            1) clear; tail -n 25 /var/log/auth.log | grep -E "Accepted|Failed|Dropped"; read -p "ENTER..." ;;
            2) clear; [ -f "/var/log/guardiao.log" ] && tail -n 25 /var/log/guardiao.log || echo "Sem logs."; read -p "ENTER..." ;;
            3) > /var/log/auth.log; echo "Logs limpos!"; sleep 1 ;;
            4) break ;;
        esac
    done
}

diagnostico_ataques() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERMELHO}RANKING DE IPS AGRESSORES (TOP 10)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    RANKING=$(grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | sort | uniq -c | sort -nr | head -n 10)
    if [ -z "$RANKING" ]; then
        echo -e "  ${VERDE}Nenhuma tentativa de ataque detectada.${NC}"
    else
        echo "$RANKING" | while read count ip; do
            printf "  ${VERMELHO}%-5s${NC} ataques de: ${AMARELO}%-15s${NC}\n" "$count" "$ip"
        done
    fi
    read -p " Pressione ENTER..." dummy
}

banir_ip() {
    read -p " Digite o IP para BANIR: " IP_ALVO
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        iptables -I INPUT -s "$IP_ALVO" -j DROP
        ufw insert 1 deny from "$IP_ALVO" to any
        echo -e "${VERDE}IP $IP_ALVO banido!${NC}"
    fi
    sleep 2
}

ssh_config() {
    if [[ "$USER_REAL" != "$ADM_USER" && "$USER_REAL" != "root" ]]; then
        echo -e "${VERMELHO}Acesso negado ao Menu SSH!${NC}"; sleep 2; return
    fi
    while true; do
        clear
        echo -e "--- CONFIGURAÇÃO SSH ---"
        echo -e "[1] Mudar Porta  [2] Login Root  [3] Voltar"
        read -n 1 OP_SSH; echo ""
        case $OP_SSH in
            1) read -p "Porta: " NP; sed -i "s/^Port .*/Port $NP/" $SSH_CONF; ufw allow "$NP"/tcp; systemctl restart ssh ;;
            2) read -p "Permitir Root? (y/n): " R; [ "$R" == "y" ] && V="yes" || V="no"; sed -i "s/^PermitRootLogin .*/PermitRootLogin $V/" $SSH_CONF; systemctl restart ssh ;;
            3) break ;;
        esac
    done
}

configurar_telegram() {
    if [[ "$USER_REAL" != "$ADM_USER" && "$USER_REAL" != "root" ]]; then
        echo -e "${VERMELHO}Acesso negado!${NC}"; sleep 2; return
    fi
    clear
    echo -e "${AMARELO}--- CONFIGURAR TELEGRAM ---${NC}"
    read -p "Token Bot: " TKN
    read -p "Chat ID: " CID
    printf "TOKEN=\"%s\"\nID_CHAT=\"%s\"\n" "$TKN" "$CID" > /etc/vps_protecao/telegram.conf
    echo -e "${VERDE}Configuração salva!${NC}"
    curl -s -X POST "https://api.telegram.org/bot$TKN/sendMessage" -d chat_id="$CID" -d text="✅ Alertas configurados!" > /dev/null
    sleep 2
}

# --- MENU PRINCIPAL ---
while true; do
    IP_EXTERNO=$(curl -s --max-time 2 ifconfig.me || echo "OFFLINE")
    PORTA_SSH=$(grep "^Port" $SSH_CONF | awk '{print $2}')
    [ -z "$PORTA_SSH" ] && PORTA_SSH="22"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "  Operador: ${AMARELO}$USER_REAL${NC} | IP: ${AZUL}$IP_EXTERNO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Ver Logs de Segurança"
    echo -e "  [2] ⚡ Testar Velocidade (Speedtest)"
    echo -e "  [3] 📊 Monitorar Tráfego Real (Live)"
    echo -e "  [4] 🛡️  Ranking de Ataques (Top 10)"
    echo -e "  [5] 🚫 Banir IP Manualmente"
    echo -e "  [6] 🔑 Configurações do SSH"
    echo -e "  [7] 📢 Configurar Alertas Telegram"
    echo -e "  [8] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) testa_velocidade ;;
        3) monitora_placa ;;
        4) diagnostico_ataques ;;
        5) banir_ip ;;
        6) ssh_config ;;
        7) configurar_telegram ;;
        8) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
