#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional
# Com alerta no telegram
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
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "          ${VERMELHO}RELATÓRIO DE ATAQUES E BANIMENTOS${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        
        # Lista Jails do Fail2Ban
        JAILS=$(fail2ban-client status | grep "Jail list" | sed 's/.*list://' | tr -d ',')
        for jail in $JAILS; do
            TOTAL=$(fail2ban-client status "$jail" | grep "Total banned" | awk '{print $4}')
            IPS=$(fail2ban-client status "$jail" | grep "Banned IP list" | sed 's/.*list://')
            echo -e "${AMARELO}[$jail]${NC} Total histórico: ${VERMELHO}$TOTAL${NC}"
            echo -e "Banidos agora: ${VERMELHO}${IPS:-Nenhum}${NC}\n"
        done

        echo -e "${AZUL}Últimos ataques (Failed Passwords):${NC}"
        grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 3
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo -e " [1] 🔓 Desbanir um IP (Fail2Ban/UFW)"
        echo -e " [2] ⬅️  Voltar ao Menu"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha uma opção: " OP_BAN; echo ""

        case $OP_BAN in
            1)
                read -p " Digite o IP para DESBANIR: " IP_DESBAN
                if [[ $IP_DESBAN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo -e "${AMARELO}Processando desbloqueio...${NC}"
                    
                    # 1. Tenta remover de todas as Jails do Fail2Ban
                    for jail in $JAILS; do
                        fail2ban-client set "$jail" unbanip "$IP_DESBAN" > /dev/null 2>&1
                    done
                    
                    # 2. Tenta remover do UFW (Regras de Deny)
                    sudo ufw delete deny from "$IP_DESBAN" > /dev/null 2>&1
                    
                    echo -e "${VERDE}✅ Comandos de desbloqueio enviados para $IP_DESBAN!${NC}"
                    
                    # Alerta opcional no Telegram
                    [ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf
                    if [[ ! -z "$TOKEN" ]]; then
                        MENSAGEM="🔓 <b>IP DESBANIDO:</b>%0AIP: <code>$IP_DESBAN</code>%0AAutor: <code>$(whoami)</code>"
                        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
                    fi
                else
                    echo -e "${VERMELHO}Formato de IP inválido!${NC}"
                fi
                sleep 2
                ;;
            2)
                break
                ;;
            *)
                echo -e "${AMARELO}Opção inválida.${NC}"
                sleep 1
                ;;
        esac
    done
}

ssh_config() {
    # --- TRAVA DE SEGURANÇA ---
    USUARIO_ATUAL=$(whoami)
    if [ "$USUARIO_ATUAL" != "jutair" ]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "O usuário '${AMARELO}$USUARIO_ATUAL${NC}' não tem permissão para configurar o SSH."
        echo -e "Esta tentativa foi registrada."
        
        # Alerta opcional no Telegram
        source /etc/vps_protecao/telegram.conf
        MENSAGEM="🚫 <b>ACESSO NEGADO:</b>%0AO usuário <code>$USUARIO_ATUAL</code> tentou entrar no Menu SSH."
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        
        sleep 3
        return # Sai da função e volta para o menu principal
    fi

    # --- INÍCIO DA FUNÇÃO ORIGINAL (APENAS PARA JUTAIR) ---
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
            4) 
                clear
                echo -e "${AMARELO}Usuários Conectados:${NC}"
                who
                echo ""
                read -p " Usuário para expulsar: " U
                # Proteção extra: Não deixa o jutair se expulsar sem querer
                if [ "$U" == "jutair" ]; then
                    echo "Você não pode expulsar a si mesmo!"; sleep 2
                else
                    pkill -u "$U" -9
                    echo "Usuário $U expulso!"; sleep 2
                fi
                ;;
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
    ufw allow 1194/udp          # OpenVPN
    ufw allow 80/tcp            # HTTP
    ufw allow 443/tcp           # HTTPS
    ufw allow 8080/tcp          # Squid Proxy
    ufw allow 7300/udp          # BadVPN UDPGW
    
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

    echo -e "${AMARELO}[5/7]${NC} Validando Guardião Auto-Kill..."
    # Ajustado para o nome correto: autokil.sh
    if [ -f "/opt/configdebian/autokil.sh" ]; then
        chmod +x /opt/configdebian/autokil.sh
        # Verifica se o arquivo de config do Telegram existe
        if [ ! -f "/etc/vps_protecao/telegram.conf" ]; then
            echo -e "${VERMELHO}⚠️ Alerta: Configuração do Telegram não encontrada!${NC}"
        fi
        # Remove agendamentos antigos e coloca o novo a cada 1 minuto
        (crontab -l 2>/dev/null | grep -v "autokil.sh"; echo "* * * * * /bin/bash /opt/configdebian/autokil.sh") | crontab -
        echo -e "${VERDE}   -> Guardião ativado no Cron (1 min).${NC}"
    else
        echo -e "${VERMELHO}   -> Erro: Script /opt/configdebian/autokil.sh não encontrado!${NC}"
    fi

    echo -e "${AMARELO}[6/7]${NC} Reiniciando Serviços de Conectividade..."
    systemctl restart squid > /dev/null 2>&1 || systemctl restart squid3 > /dev/null 2>&1
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
    local ARQUIVO_WHITE="/etc/vps_protecao/whitelist.conf"
    
    echo -e "\n${AMARELO}---------------------------------------------------------------${NC}"
    read -p " Digite o IP que deseja BANIR: " IP_ALVO
    
    # 1. Validação de formato de IP
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        
        # 2. VERIFICAÇÃO DE SEGURANÇA (WHITELIST)
        # Verifica se o IP alvo existe dentro do arquivo de whitelist
        if [ -f "$ARQUIVO_WHITE" ] && grep -q "^$IP_ALVO$" "$ARQUIVO_WHITE"; then
            echo -e "${VERMELHO}❌ OPERAÇÃO BLOQUEADA!${NC}"
            echo -e "${AMARELO}O IP $IP_ALVO está na Lista Branca e não pode ser banido.${NC}"
            
            # Alerta o jutair no Telegram sobre a tentativa de banir um IP protegido
            [ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf
            if [[ ! -z "$TOKEN" ]]; then
                MENSAGEM="🛡️ <b>AVISO:</b> O usuário <code>$(whoami)</code> tentou banir o IP protegido <code>$IP_ALVO</code>!"
                curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
            fi
        else
            # 3. Executa o banimento se não estiver na whitelist
            echo -e "${VERMELHO}Bloqueando IP: $IP_ALVO...${NC}"
            sudo ufw insert 1 deny from "$IP_ALVO" to any
            echo -e "${VERDE}O IP $IP_ALVO foi banido com sucesso!${NC}"
        fi
    else
        echo -e "${VERMELHO}Formato de IP inválido!${NC}"
    fi
    echo -e "${AMARELO}---------------------------------------------------------------${NC}"
    sleep 2
}

gerenciar_whitelist() {
    # APENAS JUTAIR MEXE NA LISTA
    if [ "$(whoami)" != "jutair" ]; then
        echo -e "${VERMELHO}Acesso negado! Apenas o administrador jutair gerencia a Whitelist.${NC}"
        sleep 2; return
    fi

    local ARQUIVO_WHITE="/etc/vps_protecao/whitelist.conf"
    [ ! -d "/etc/vps_protecao" ] && mkdir -p /etc/vps_protecao
    touch "$ARQUIVO_WHITE"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAR LISTA BRANCA (IP)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e " [1] Adicionar IP à Lista Branca"
    echo -e " [2] Ver IPs Protegidos"
    echo -e " [3] Remover IP da Lista Branca"
    echo -e " [4] Voltar"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha: " OP_W; echo ""

    case $OP_W in
        1)
            read -p " IP para proteger: " IP_W
            if [[ $IP_W =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$IP_W" >> "$ARQUIVO_WHITE"
                sudo ufw allow from "$IP_W" to any
                echo -e "${VERDE}IP $IP_W protegido com sucesso!${NC}"
            fi ;;
        2)
            echo -e "${AMARELO}Lista de IPs Protegidos:${NC}"
            cat "$ARQUIVO_WHITE"
            read -p "Pressione enter..." ;;
        3)
            read -p " IP para remover a proteção: " IP_R
            sed -i "/^$IP_R$/d" "$ARQUIVO_WHITE"
            sudo ufw delete allow from "$IP_R" to any
            echo -e "${AMARELO}Proteção removida para o IP $IP_R.${NC}" ;;
        *) return ;;
    esac
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
configurar_telegram() {
    # --- TRAVA DE SEGURANÇA ---
    USUARIO_ATUAL=$(whoami)
    if [ "$USUARIO_ATUAL" != "jutair" ]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "O usuário '${AMARELO}$USUARIO_ATUAL${NC}' não pode configurar alertas."
        
        # Alerta o dono no Telegram sobre a tentativa de mexer nas configurações
        # Tenta carregar o token atual para avisar do acesso negado
        [ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf
        if [[ ! -z "$TOKEN" ]]; then
            MENSAGEM="🚫 <b>TENTATIVA DE ACESSO:</b>%0AO usuário <code>$USUARIO_ATUAL</code> tentou alterar as configurações do Telegram!"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        
        sleep 3
        return
    fi

    # --- INÍCIO DA CONFIGURAÇÃO (APENAS PARA JUTAIR) ---
    clear
    echo -e "\033[1;33m--- CONFIGURAR ALERTA TELEGRAM ---\033[0m"
    echo ""
    read -p "Digite o Token do seu Bot: " NOVO_TOKEN
    read -p "Digite o seu ID do Telegram: " NOVO_ID
    echo ""

    # Cria o diretório se não existir
    sudo mkdir -p /etc/vps_protecao

    # Grava no arquivo limpando o conteúdo anterior (sem o -a no primeiro tee)
    echo "TOKEN=\"$NOVO_TOKEN\"" | sudo tee /etc/vps_protecao/telegram.conf > /dev/null
    echo "ID_CHAT=\"$NOVO_ID\"" | sudo tee -a /etc/vps_protecao/telegram.conf > /dev/null

    # Garante que o arquivo seja legível pelo script, mas protegido
    sudo chmod 644 /etc/vps_protecao/telegram.conf

    echo -e "\033[1;32mConfiguração salva com sucesso!\033[0m"
    
    # Teste de envio imediato
    echo "Enviando teste para o seu Telegram..."
    curl -s -X POST "https://api.telegram.org/bot$NOVO_TOKEN/sendMessage" \
         -d chat_id="$NOVO_ID" \
         -d text="✅ Alertas da VPS configurados com sucesso para o usuário JUTAIR!" > /dev/null
         
    sleep 2
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
    echo -e "  [7] 📢 Configurar Alertas ✈️  Telegram"
    echo -e "  [8] ⬅️  Retornar ao Menu Principal"
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
                echo -e "           ${VERMELHO}DASHBOARD DE SEGURANÇA E FIREWALL${NC}"
                echo -e "${AZUL}===============================================================${NC}"
                printf "  ${AZUL}%-18s :${NC} ${VERMELHO}%-20s${NC}\n" "TENTATIVAS ATAQUE" "$ATAQUES (Log atual)"
                printf "  ${AZUL}%-18s :${NC} ${VERDE}%-20s${NC}\n" "PORTAS ABERTAS" "$PORTAS_ABERTAS"
                echo -e "${AZUL}===============================================================${NC}"
                echo -e "  [1] 📋 Ver Regras Detalhadas (UFW)"
                echo -e "  [2] 🚫 Ver IPs Banidos (Fail2Ban)"
                echo -e "  [3] 🔍 Ranking de IPs Agressores (Top 10)" 
                echo -e "  [4] 🔨 Banir um IP Manualmente"           
                echo -e "  [5] 📑 Gerenciar White List"            
                echo -e "  [6] 🔓 Abrir Nova Porta"
                echo -e "  [7] 🛡️  RESTAURAR SEGURANÇA PADRÃO"
                echo -e "  [8] ⬅️  Voltar"
                echo -e "${AZUL}---------------------------------------------------------------${NC}"
                read -n 1 -p " Digite a opção: " FO; echo ""

                case $FO in
                    1) ufw status numbered; read -p " ENTER para voltar..." d ;;
                    2) monitora_banidos ;;
                    3) diagnostico_ataques ;; # Chamada da função de Ranking
                    4) banir_ip ;;           # Chamada da função de Banimento
                    5) restaura_seguranca ;;
                    6) read -p " Porta: " P; ufw allow "$P"; echo -e "${VERDE}Porta $P aberta!${NC}"; sleep 2 ;;
                    7) restaura seguranca ;;
                    8) break ;;
                    *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
                esac
            done ;;
        6) ssh_config ;;
        7) configurar_telegram ;;
        8) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
