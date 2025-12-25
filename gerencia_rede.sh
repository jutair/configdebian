#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional

# --- VARIÁVEIS E CORES ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)
SSH_CONF="/etc/ssh/sshd_config"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C
trap '' SIGINT

# --- FUNÇÕES DE APOIO ---

testa_velocidade() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Aguarde, testando a conexão da VPS...${NC}"
    speedtest-cli --simple
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitora_placa() {
    clear
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    echo -e "${AMARELO}Monitorando interface: $INTERFACE (CTRL+C para parar)${NC}"
    vnstat -l -i "$INTERFACE"
}

monitora_banidos() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERMELHO}RELATÓRIO DE ATAQUES E BANIMENTOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    JAILS=$(fail2ban-client status | grep "Jail list" | sed 's/.*list://' | tr -d ',')
    for jail in $JAILS; do
        TOTAL=$(fail2ban-client status "$jail" | grep "Total banned" | awk '{print $4}')
        IPS=$(fail2ban-client status "$jail" | grep "Banned IP list" | sed 's/.*list://')
        echo -e "${AMARELO}[$jail]${NC} Total histórico: ${VERMELHO}$TOTAL${NC}"
        echo -e "Banidos agora: ${VERMELHO}${IPS:-Nenhum}${NC}\n"
    done
    echo -e "${AZUL}Últimos ataques (Failed Passwords):${NC}"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

ssh_config() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH"
        echo -e "  [2] 👤 Permitir/Bloquear Login Root"
        echo -e "  [3] 🔑 Permitir/Bloquear Senhas (Password Auth)"
        echo -e "  [4] 👢 Desconectar Usuário Ativo"
        echo -e "  [5] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Digite a opção: " OP; echo ""
        case $OP in
            1) read -p " Nova Porta: " NP; ufw allow "$NP"/tcp; sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" >> $SSH_CONF; systemctl restart ssh ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            3) echo -e "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            4) clear; who; read -p " Usuário para expulsar: " U; pkill -u "$U" -9; echo "Expulso!"; sleep 2 ;;
            5) break ;;
        esac
    done
}

restaura_seguranca() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           ${AMARELO}RESTAURANDO CONFIGURAÇÕES DE SEGURANÇA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    echo -e "${AMARELO}[1/7]${NC} Resetando regras do UFW..."
    ufw --force reset > /dev/null
    ufw default deny incoming > /dev/null
    ufw default allow outgoing > /dev/null

    echo -e "${AMARELO}[2/7]${NC} Aplicando portas padrão (SSH, VPN e Proxy)..."
    PORTA_SSH=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$PORTA_SSH" ] && PORTA_SSH="22"
    
    ufw allow "$PORTA_SSH"/tcp  # SSH
    ufw allow 1194/udp         # OpenVPN
    ufw allow 80/tcp           # HTTP
    ufw allow 443/tcp          # HTTPS
    ufw allow 8080/tcp         # Squid Proxy (Porta padrão)
    ufw allow 7300/udp         # BadVPN UDPGW (Jogos)
    
    echo -e "${AMARELO}[3/7]${NC} Otimizando Kernel (BBR & Anti-Spoofing)..."
    sed -i '/net.ipv4.conf.all.rp_filter/d' /etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1

    echo -e "${AMARELO}[4/7]${NC} Aplicando Hardening no SSH..."
    sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
    sed -i '/MaxAuthTries/d' /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    echo "MaxAuthTries 5" >> /etc/ssh/sshd_config
    systemctl restart ssh

    echo -e "${AMARELO}[5/7]${NC} Validando Guardião Auto-Kill (Background)..."
    if [ -f "/opt/configdebian/auto_kill.sh" ]; then
        chmod +x /opt/configdebian/auto_kill.sh
        (crontab -l 2>/dev/null | grep -v "auto_kill.sh"; echo "*/2 * * * * /bin/bash /opt/configdebian/auto_kill.sh") | crontab -
        /bin/bash /opt/configdebian/auto_kill.sh # Checagem imediata
    fi

    echo -e "${AMARELO}[6/7]${NC} Reiniciando Serviços de Conectividade..."
    # Reinicia Squid se estiver instalado
    systemctl restart squid > /dev/null 2>&1 || systemctl restart squid3 > /dev/null 2>&1
    # Reinicia BadVPN (ajuste o nome do serviço se for diferente)
    systemctl restart badvpn-udpgw > /dev/null 2>&1
    
    echo -e "${AMARELO}[7/7]${NC} Ativando serviços de proteção..."
    ufw --force enable > /dev/null
    systemctl restart fail2ban > /dev/null 2>&1
    
    echo -e "${VERDE}✅ SEGURANÇA E SERVIÇOS RESTAURADOS COM SUCESSO!${NC}"
    sleep 3
}
visualizar_logs() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${AMARELO}📊 MONITOR DE LOGS DO SISTEMA${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🦑 Log de Acesso do Squid (Proxy)"
        echo -e "  [2] 🎮 Log do BadVPN (UDP-GW)"
        echo -e "  [3] 🛡️  Log do Auto-Kill (Segurança)"
        echo -e "  [4] 🔐 Log de Autenticação (SSH/Falhas)"
        echo -e "  [5] 🧹 Limpar Todos os Logs (Reset)"
        echo -e "  [6] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha uma opção: " OP_LOG; echo ""

        case $OP_LOG in
            1)
                LOG_SQUID="/var/log/squid/access.log"
                [ ! -f "$LOG_SQUID" ] && LOG_SQUID="/var/log/squid3/access.log"
                clear
                echo -e "${VERDE}--- ÚLTIMAS CONEXÕES SQUID ---${NC}"
                if [ -f "$LOG_SQUID" ]; then
                    tail -n 20 "$LOG_SQUID" | awk '{print "IP: " $3 " -> Destino: " $7}'
                else
                    echo "Arquivo de log não encontrado."
                fi
                echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"
                read -r
                ;;
            2)
                clear
                echo -e "${VERDE}--- ÚLTIMOS LOGS BADVPN ---${NC}"
                grep "badvpn" /var/log/syslog | tail -n 20
                echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"
                read -r
                ;;
            3)
                clear
                echo -e "${VERDE}--- HISTÓRICO AUTO-KILL ---${NC}"
                if [ -f "/var/log/vps_autokill.log" ]; then
                    tail -n 20 /var/log/vps_autokill.log
                else
                    echo "Nenhum registro de segurança ainda."
                fi
                echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"
                read -r
                ;;
            4)
                clear
                echo -e "${VERDE}--- TENTATIVAS DE ACESSO SSH ---${NC}"
                tail -n 20 /var/log/auth.log | grep -E "Accepted|Failed|Dropped"
                echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"
                read -r
                ;;
            5)
                echo -e "\n${VERMELHO}⚠️ Deseja realmente limpar todos os logs de segurança e proxy?${NC}"
                read -p " Confirmar limpeza? (s/n): " CONFIRM
                if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
                    # Limpa o Log do Auto-Kill
                    [ -f "/var/log/vps_autokill.log" ] && > /var/log/vps_autokill.log
                    # Limpa o Log do Squid
                    LOG_SQUID="/var/log/squid/access.log"
                    [ ! -f "$LOG_SQUID" ] && LOG_SQUID="/var/log/squid3/access.log"
                    [ -f "$LOG_SQUID" ] && > "$LOG_SQUID"
                    
                    echo -e "${VERDE}✅ Logs limpos com sucesso!${NC}"
                    sleep 2
                fi
                ;;
            6)
                return
                ;;
            *)
                echo -e "${VERMELHO}Opção inválida!${NC}"
                sleep 1
                ;;
        esac
    done
}
banir_ip() {
    echo -e "\n${AMARELO}---------------------------------------------------------------${NC}"
    read -p " Digite o IP que deseja BANIR: " IP_ALVO
    
    # Validação simples de formato de IP
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${VERMELHO}Bloqueando IP: $IP_ALVO...${NC}"
        # Adiciona a regra de rejeição no topo para garantir prioridade
        ufw insert 1 deny from "$IP_ALVO" to any
        echo -e "${VERDE}O IP $IP_ALVO foi banido com sucesso!${NC}"
    else
        echo -e "${VERMELHO}Formato de IP inválido!${NC}"
    fi
    echo -e "${AMARELO}---------------------------------------------------------------${NC}"
    sleep 2
}
diagnostico_ataques() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERMELHO}RANKING DE IPS AGRESSORES (TOP 10)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Analisando logs de autenticação...${NC}\n"
    
    # Extrai IPs que falharam no login, conta a frequência e mostra o Top 10
    RANKING=$(grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | sort | uniq -c | sort -nr | head -n 10)
    
    if [ -z "$RANKING" ]; then
        echo -e "  ${VERDE}Nenhuma tentativa de ataque detectada nos logs.${NC}"
    else
        echo "$RANKING" | while read count ip; do
            printf "  ${VERMELHO}%-5s${NC} tentativas vindas de: ${AMARELO}%-15s${NC}\n" "$count" "$ip"
        done
    fi
    
    echo -e "\n${AZUL}---------------------------------------------------------------${NC}"
    echo -e "Dica: Identifique os IPs acima e use a opção [4] para banir."
    read -p " Pressione ENTER para retornar..." dummy
}
# --- MENU PRINCIPAL DO MÓDULO ---

while true; do
    IP_EXTERNO=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")
    PORTA_SSH=$(grep "^Port" $SSH_CONF | awk '{print $2}')
    [ -z "$PORTA_SSH" ] && PORTA_SSH="22"
    IFACE_PRINCIPAL=$(ip route | grep default | awk '{print $5}')
    TOTAL_BAN=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
    [ -z "$TOTAL_BAN" ] && TOTAL_BAN="0"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "IP SERVIDOR" "$IP_EXTERNO"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "PORTA SSH" "$PORTA_SSH"
    printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "INTERFACE" "$IFACE_PRINCIPAL"
    printf "  ${AZUL}%-15s :${NC} ${VERMELHO}%-20s${NC}\n" "IPs BANIDOS" "$TOTAL_BAN (Fail2Ban)"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Ver Logs de Segurança"
    echo -e "  [2] ⚡ Testar Velocidade"
    echo -e "  [3] 📊 Monitorar Tráfego Real (Live)"
    echo -e "  [4] 📉 Relatórios de Consumo (VnStat)"
    echo -e "  [5] 🛡️  Firewall e Fail2Ban (Banimentos)"
    echo -e "  [6] 🔑 Configurações do SSH"
    echo -e "  [7] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) testa_velocidade ;;
        3) monitora_placa ;;
        4) 
            while true; do
                clear
                echo "=== Relatórios VnStat ($IFACE_PRINCIPAL) ==="
                echo "[1] Diário  [2] Mensal  [3] Voltar"
                read -n 1 -p "Opção: " VO; echo ""
                case $VO in
                    1) vnstat -d; read -p "ENTER..." d ;;
                    2) vnstat -m; read -p "ENTER..." d ;;
                    3) break ;;
                esac
            done ;;
        5)  
            while true; do
                # Dados para o Dashboard de Segurança
                ATAQUES=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
                PORTAS_ABERTAS=$(ufw status | grep "ALLOW" | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/ $//')
                [ -z "$PORTAS_ABERTAS" ] && PORTAS_ABERTAS="Nenhuma (Bloqueio Total)"

                clear
                echo -e "${AZUL}===============================================================${NC}"
                echo -e "                ${VERMELHO}DASHBOARD DE SEGURANÇA E FIREWALL${NC}"
                echo -e "${AZUL}===============================================================${NC}"
                printf "  ${AZUL}%-18s :${NC} ${VERMELHO}%-20s${NC}\n" "TENTATIVAS ATAQUE" "$ATAQUES (Log atual)"
                printf "  ${AZUL}%-18s :${NC} ${VERDE}%-20s${NC}\n" "PORTAS ABERTAS" "$PORTAS_ABERTAS"
                echo -e "${AZUL}===============================================================${NC}"
                echo -e "  [1] 📋 Ver Regras Detalhadas (UFW)"
                echo -e "  [2] 🚫 Ver IPs Banidos (Fail2Ban)"
                echo -e "  [3] 🔍 Ranking de IPs Agressores (Top 10)" # <-- NOVA FUNÇÃO
                echo -e "  [4] 🔨 Banir um IP Manualmente"            # <-- NOVA FUNÇÃO
                echo -e "  [5] 🔓 Abrir Nova Porta"
                echo -e "  [6] 🛡️  RESTAURAR SEGURANÇA PADRÃO"
                echo -e "  [7] ⬅️  Voltar"
                echo -e "${AZUL}---------------------------------------------------------------${NC}"
                read -n 1 -p " Digite a opção: " FO; echo ""

                case $FO in
                    1) ufw status numbered; read -p " ENTER para voltar..." d ;;
                    2) monitora_banidos ;;
                    3) diagnostico_ataques ;; # Chamada da função de Ranking
                    4) banir_ip ;;           # Chamada da função de Banimento
                    5) read -p " Porta: " P; ufw allow "$P"; echo -e "${VERDE}Porta $P aberta!${NC}"; sleep 2 ;;
                    6) restaura_seguranca ;;
                    7) break ;;
                    *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
                esac
            done ;;
        6) ssh_config ;;
        7) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
