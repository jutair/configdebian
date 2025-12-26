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

# Verifica Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

trap '' SIGINT SIGTSTP

# --- 2. FUNÇÃO DE VALIDAÇÃO DE PERMISSÃO ---
verificar_permissao() {
    if [[ "$USER_OPERADOR" != "$ADM_USER" ]]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "Operador: ${AMARELO}$USER_OPERADOR${NC} | Admin Requerido: ${VERDE}$ADM_USER${NC}"
        
        # Alerta Telegram sobre tentativa de acesso
        [ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
        if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
            MENSAGEM="🚫 <b>TENTATIVA DE ACESSO:</b>%0AOperador <code>$USER_OPERADOR</code> tentou acessar função de Admin em Rede/SSH."
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 2
        return 1
    fi
    return 0
}

############################ FUNÇÕES DE MONITORAMENTO ############################

visualizar_logs() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                📊 MONITOR DE LOGS DO SISTEMA"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🔐 Log de Autenticação SSH (Logins)\n  [2] 🛡️  Log do Fail2Ban (Banimentos)\n  [3] 🧹 Limpar Logs de Acesso (Admin)\n  [4] ⬅️  Voltar"
        read -n 1 -p " Opção: " OP_LOG; echo ""
        case $OP_LOG in
            1) tail -n 25 /var/log/auth.log | grep -E "Accepted|Failed"; read -p "Pressione ENTER..." d ;;
            2) tail -n 25 /var/log/fail2ban.log; read -p "Pressione ENTER..." d ;;
            3) verificar_permissao && { > /var/log/auth.log; echo "Logs limpos com sucesso."; sleep 2; } ;;
            4) break ;;
        esac
    done
}

testa_velocidade() {
    clear
    echo -e "${AMARELO}🚀 Testando velocidade da rede (Aguarde)...${NC}"
    speedtest-cli --simple || echo -e "${VERMELHO}Erro: speedtest-cli não encontrado.${NC}"
    read -p "Pressione ENTER para voltar..." d
}

############################ FUNÇÕES DE SEGURANÇA ############################

ssh_config() {
    verificar_permissao || return
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                🔑 CONFIGURAÇÕES DE SSH"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Alterar Porta SSH\n  [2] 👤 Permitir/Bloquear Root\n  [3] ⬅️  Voltar"
        read -n 1 -p " Escolha: " OP_SSH; echo ""
        case $OP_SSH in
            1) read -p " Digite a nova porta: " NP
               ufw allow "$NP"/tcp
               sed -i "/^Port /d" $SSH_CONF
               echo "Port $NP" >> $SSH_CONF
               systemctl restart ssh && echo -e "${VERDE}Porta alterada para $NP!${NC}"
               sleep 2 ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R
               [ "$R" == "1" ] && VAL="yes" || VAL="no"
               sed -i "/^PermitRootLogin/d" $SSH_CONF
               echo "PermitRootLogin $VAL" >> $SSH_CONF
               systemctl restart ssh; sleep 2 ;;
            3) break ;;
        esac
    done
}

restaura_seguranca_total() {
    clear
    echo -e "${VERMELHO}===============================================================${NC}"
    echo -e "          🛡️  RESTAURAÇÃO DE SEGURANÇA PADRÃO"
    echo -e "${VERMELHO}===============================================================${NC}"
    echo -e "Esta ação irá:\n1. Voltar SSH para porta 22\n2. Resetar e Reativar Firewall\n3. Reiniciar o Guardião"
    read -p "Confirmar reset de segurança? (s/n): " CONFIRM
    [[ "$CONFIRM" != "s" ]] && return

    echo -e "${AMARELO}⏳ Aplicando blindagem...${NC}"

    # 1. SSH Padrão
    sed -i "/^Port /d" $SSH_CONF
    echo "Port 22" >> $SSH_CONF
    
    # 2. Firewall Reset (IPTables + UFW)
    iptables -F && iptables -X
    iptables -P INPUT DROP
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    ufw --force reset >/dev/null
    ufw default deny incoming >/dev/null
    for p in 22/tcp 80/tcp 443/tcp 8080/tcp 1194/udp; do ufw allow $p >/dev/null; done
    ufw --force enable >/dev/null

    # 3. Guardião
    pkill -f "guardiao.sh" > /dev/null 2>&1 || true
    [ -f "$DIR_CONFIG/guardiao.sh" ] && nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

    systemctl restart ssh fail2ban
    
    # Notificação ao Admin
    [ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
    if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
        MENSAGEM="🛡️ <b>SECURITY RESET:</b> Operador <code>$USER_OPERADOR</code> restaurou a segurança padrão."
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
    fi
    echo -e "${VERDE}✅ Sistema Restaurado e Protegido!${NC}"; sleep 3
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
    printf "  %-15s : ${AMARELO}%-20s${NC}\n" "PORTA SSH" "$PORTA_SSH"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Logs de Segurança        [5] 🛡️  Gerenciar Firewall (Admin)"
    echo -e "  [2] ⚡ Testar Velocidade        [6] 🔑 Configurações SSH (Admin)"
    echo -e "  [3] 📊 Tráfego Live (VNSTAT)    [7] 📢 Configurar Telegram (Admin)"
    echo -e "  [4] 🛡️  RESTAURAR SEGURANÇA PADRÃO (LIBERADO)"
    echo -e "  [8] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) testa_velocidade ;;
        3) INTERFACE=$(ip route | grep default | awk '{print $5}')
           vnstat -l -i "$INTERFACE" ;;
        4) restaura_seguranca_total ;;
        5) verificar_permissao && { 
             read -p "IP para Banir: " IPB
             ufw deny from "$IPB" && echo "Banido!"; sleep 2
           } ;;
        6) ssh_config ;;
        7) if verificar_permissao; then
             read -p "Bot Token: " TK; read -p "Chat ID: " CID
             echo "TOKEN=\"$TK\"" > "$DIR_PROT/telegram.conf"
             echo "ID_CHAT=\"$CID\"" >> "$DIR_PROT/telegram.conf"
             echo "Configuração salva!"; sleep 2
           fi ;;
        8) exit 0 ;;
    esac
done
