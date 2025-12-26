#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional
# Atualizado: 26-12-2025

# --- 1. CONFIGURAÇÕES E DIRETÓRIOS ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
ADMIN_CONF="$DIR_PROT/admin.conf"
SSH_CONF="/etc/ssh/sshd_config"

# Cores
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Carrega o Admin cadastrado
[ -f "$ADMIN_CONF" ] && source "$ADMIN_CONF" || ADM_USER="NAO_CONFIGURADO"

# Detecta Operador Atual
USER_OPERADOR=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})

if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

trap '' SIGINT SIGTSTP

# --- 2. FUNÇÃO DE VALIDAÇÃO DE PERMISSÃO (Para funções restritas) ---
verificar_permissao() {
    if [[ "$USER_OPERADOR" != "$ADM_USER" ]]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "Operador: ${AMARELO}$USER_OPERADOR${NC} | Admin: ${VERDE}$ADM_USER${NC}"
        
        [ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
        if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
            MENSAGEM="🚫 <b>ALERTA:</b> Operador <code>$USER_OPERADOR</code> tentou acessar funções restritas!"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 2
        return 1
    fi
    return 0
}

############################ FUNÇÃO DE RESET (LIBERADA) ############################

restaura_seguranca_total() {
    clear
    echo -e "${VERMELHO}⚠️ RESTAURAÇÃO DE SEGURANÇA PADRÃO (LIBERADO)${NC}"
    echo -e "Isso voltará o SSH para porta 22 e resetará o Firewall."
    read -p "Confirmar restauração? (s/n): " CONFIRM
    [[ "$CONFIRM" != "s" ]] && return

    echo -e "${AMARELO}🛡️ Iniciando Blindagem Padrão...${NC}"

    # 1. Reset SSH Porta 22
    sed -i "/^Port /d" $SSH_CONF
    echo "Port 22" >> $SSH_CONF
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONF

    # 2. IPTables (Limpeza e Proteção)
    iptables -F && iptables -X
    iptables -P INPUT DROP && iptables -P FORWARD DROP && iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # 3. UFW (Reset e Regras Essenciais)
    ufw --force reset >/dev/null
    ufw default deny incoming >/dev/null
    for p in 22/tcp 80/tcp 443/tcp 8080/tcp 1194/udp; do ufw allow $p >/dev/null; done
    ufw --force enable >/dev/null

    # 4. Reiniciar Guardião
    pkill -f "guardiao.sh" > /dev/null 2>&1 || true
    [ -f "$DIR_CONFIG/guardiao.sh" ] && nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

    # 5. Reiniciar Serviços
    systemctl restart ssh fail2ban
    echo -e "${VERDE}✅ SEGURANÇA PADRÃO RESTAURADA! (SSH: 22)${NC}"
    
    # Notifica o Admin via Telegram que alguém resetou a segurança
    [ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
    if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
        MENSAGEM="🛡️ <b>RESTAURAÇÃO DE SEGURANÇA:</b>%0AOperador <code>$USER_OPERADOR</code> resetou as configurações para o padrão seguro."
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
    fi
    sleep 3
}

############################ MENU PRINCIPAL ############################

while true; do
    PORTA_SSH=$(grep "^Port" $SSH_CONF | awk '{print $2}' | head -1)
    [[ -z "$PORTA_SSH" ]] && PORTA_SSH="22"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "  OPERADOR: ${AMARELO}$USER_OPERADOR${NC} | ADMIN: ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Logs de Segurança        [5] 🛡️  Gerenciar Firewall (Admin)"
    echo -e "  [2] ⚡ Testar Velocidade        [6] 🔑 Configurações SSH (Admin)"
    echo -e "  [3] 📊 Tráfego Live (VNSTAT)    [7] 📢 Configurar Telegram (Admin)"
    echo -e "  [4] 🛡️  RESTAURAR SEGURANÇA PADRÃO"
    echo -e "  [8] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) Visualizar logs... ;; # Adicione aqui sua função de logs
        2) speedtest-cli --simple; read -p "ENTER..." d ;;
        3) INTERFACE=$(ip route | grep default | awk '{print $5}'); vnstat -l -i "$INTERFACE" ;;
        4) restaura_seguranca_total ;;
        5) verificar_permissao && { echo "Gestão de Firewall..."; sleep 1; } ;;
        6) verificar_permissao && { echo "Config SSH..."; sleep 1; } ;;
        7) verificar_permissao && { echo "Config Telegram..."; sleep 1; } ;;
        8) exit 0 ;;
    esac
done
