#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional (Versão Restaurada)

# --- 1. DETECÇÃO ROBUSTA DO USUÁRIO ---
# Busca o admin definido centralmente ou assume 'jutair' como padrão
DIR_PROT="/etc/vps_protecao"
[ -f "$DIR_PROT/admin.conf" ] && source "$DIR_PROT/admin.conf"
[[ -z "$ADM_USER" ]] && ADM_USER="jutair"

# Detecta quem está operando o script agora
USER_REAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
SSH_CONF="/etc/ssh/sshd_config"

# Cores
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C
trap '' SIGINT

# --- FUNÇÃO DE VALIDAÇÃO DE ADMIN ---
verificar_permissao() {
    if [[ "$USER_REAL" != "$ADM_USER" ]]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "O usuário '${AMARELO}$USER_REAL${NC}' não tem permissão para esta ação."
        
        # Alerta Telegram
        [ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
        if [[ -n "$TOKEN" ]]; then
            MENSAGEM="🚫 <b>TENTATIVA DE ACESSO NEGADO:</b>%0AOperador: <code>$USER_REAL</code> tentou acessar função restrita de Rede/SSH."
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3
        return 1 # Falha
    fi
    return 0 # Sucesso
}

############################ FUNÇÕES DE REDE ############################

testa_velocidade() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Aguarde, testando a conexão da VPS...${NC}"
    speedtest-cli --simple || echo -e "${VERMELHO}Instale speedtest-cli para usar esta função.${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitora_placa() {
    clear
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    echo -e "${AMARELO}Monitorando interface: $INTERFACE (CTRL+C para parar)${NC}"
    vnstat -l -i "$INTERFACE"
}

visualizar_logs() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${AMARELO}📊 MONITOR DE LOGS DO SISTEMA${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🦑 Log de Acesso do Squid\n  [2] 🎮 Log do BadVPN\n  [3] 🛡️  Log do Auto-Kill\n  [4] 🔐 Log de Autenticação SSH\n  [5] 🧹 Limpar Logs\n  [6] ⬅️  Voltar"
        read -n 1 -p " Opção: " OP_LOG; echo ""
        case $OP_LOG in
            1) tail -n 20 /var/log/squid/access.log 2>/dev/null || tail -n 20 /var/log/squid3/access.log 2>/dev/null; read -p "ENTER..." d ;;
            2) grep "badvpn" /var/log/syslog | tail -n 20; read -p "ENTER..." d ;;
            3) tail -n 20 /var/log/vps_autokill.log 2>/dev/null; read -p "ENTER..." d ;;
            4) tail -n 20 /var/log/auth.log | grep -E "Accepted|Failed"; read -p "ENTER..." d ;;
            5) verificar_permissao && { > /var/log/auth.log; echo "Logs limpos."; sleep 2; } ;;
            6) return ;;
        esac
    done
}

############################ FUNÇÕES DE SEGURANÇA ############################

ssh_config() {
    verificar_permissao || return
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH\n  [2] 👤 Login Root\n  [3] 🔑 Auth por Senha\n  [4] 👢 Expulsar Usuário\n  [5] ⬅️  Voltar"
        read -n 1 -p " Escolha: " OP; echo ""
        case $OP in
            1) read -p " Nova Porta: " NP; ufw allow "$NP"/tcp; sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" >> $SSH_CONF; systemctl restart ssh ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            3) echo -e "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            4) who; read -p "Usuário para expulsar: " U; [[ "$U" != "$ADM_USER" ]] && pkill -u "$U" -9 || echo "Ação negada!"; sleep 2 ;;
            5) break ;;
        esac
    done
}

restaura_seguranca() {
    verificar_permissao || return
    clear
    echo -e "${AMARELO}Restaurando Firewall, BBR e Serviços...${NC}"
    ufw --force reset >/dev/null
    ufw default deny incoming >/dev/null
    ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 8080/tcp; ufw allow 1194/udp
    
    # BBR
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    
    ufw --force enable
    systemctl restart ssh fail2ban
    echo -e "${VERDE}✅ Configurações padrão aplicadas!${NC}"
    sleep 3
}

banir_ip() {
    read -p " IP para BANIR: " IP_ALVO
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9] ]]; then
        # Verifica Whitelist
        if grep -q "^$IP_ALVO$" "$DIR_PROT/whitelist.conf" 2>/dev/null; then
            echo -e "${VERMELHO}IP protegido na Whitelist!${NC}"; sleep 2
        else
            iptables -I INPUT -s "$IP_ALVO" -j DROP
            iptables -I FORWARD -d "$IP_ALVO" -j DROP
            ufw insert 1 deny from "$IP_ALVO" to any >/dev/null
            echo -e "${VERDE}IP $IP_ALVO isolado!${NC}"; sleep 2
        fi
    fi
}

############################ MENU PRINCIPAL ############################

while true; do
    IP_EXTERNO=$(curl -s --max-time 2 ifconfig.me || echo "OFFLINE")
    PORTA_SSH=$(grep "^Port" $SSH_CONF | awk '{print $2}' | head -1)
    [[ -z "$PORTA_SSH" ]] && PORTA_SSH="22"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "  Operador: ${AMARELO}$USER_REAL${NC} | Admin: ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  %-15s : ${AMARELO}%-20s${NC}\n" "IP SERVIDOR" "$IP_EXTERNO"
    printf "  %-15s : ${AMARELO}%-20s${NC}\n" "PORTA SSH" "$PORTA_SSH"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Logs de Segurança        [5] 🛡️  Firewall/Fail2Ban"
    echo -e "  [2] ⚡ Testar Velocidade        [6] 🔑 Configurações SSH"
    echo -e "  [3] 📊 Tráfego Live (VNSTAT)    [7] 📢 Configurar Telegram"
    echo -e "  [4] 📉 Relatórios de Consumo    [8] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) testa_velocidade ;;
        3) monitora_placa ;;
        4) vnstat -d; read -p "ENTER..." d ;;
        5) # Submenu de Firewall
           while true; do
               clear
               echo -e "${VERMELHO}--- GESTÃO DE BANIMENTOS ---${NC}"
               echo -e " [1] Ranking Agressores\n [2] Banir IP Manual\n [3] Whitelist\n [4] Restaurar Tudo\n [5] Voltar"
               read -n 1 -p " Escolha: " FO; echo ""
               case $FO in
                   1) grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -n 10; read -p "ENTER..." d ;;
                   2) banir_ip ;;
                   3) if [[ "$USER_REAL" == "$ADM_USER" ]]; then 
                        read -p "IP para Whitelist: " IW; echo "$IW" >> "$DIR_PROT/whitelist.conf"; echo "Adicionado."; sleep 1
                      else echo "Negado."; sleep 1; fi ;;
                   4) restaura_seguranca ;;
                   5) break ;;
               esac
           done ;;
        6) ssh_config ;;
        7) # Configurar Telegram
            if verificar_permissao; then
                read -p "Bot Token: " TK; read -p "Chat ID: " CID
                mkdir -p "$DIR_PROT"
                echo "TOKEN=\"$TK\"" > "$DIR_PROT/telegram.conf"
                echo "ID_CHAT=\"$CID\"" >> "$DIR_PROT/telegram.conf"
                echo "Configurado!"; sleep 2
            fi ;;
        8) exit 0 ;;
    esac
done
