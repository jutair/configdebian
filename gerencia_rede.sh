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

ssh_config() {
    verificar_permissao || return
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "  ADMINISTRADOR ATIVO: ${AMARELO}$ADM_USER${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH\n  [2] 👤 Permitir/Bloquear Login Root\n  [3] 🔑 Password Auth\n  [4] 👢 Desconectar Usuário Ativo\n  [5] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Digite a opção: " OP; echo ""
        case $OP in
            1) read -p " Nova Porta: " NP; ufw allow "$NP"/tcp; sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" >> $SSH_CONF; systemctl restart ssh ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            3) echo -e "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            4) clear; who; read -p " Usuário para expulsar: " U; [[ "$U" == "$ADM_USER" ]] && echo "Erro: Auto-expulsão negada!" || pkill -u "$U" -9 ;;
            5) break ;;
        esac
    done
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

monitora_banidos() {
    # Verifica se o fail2ban-client existe para evitar erros
    if ! command -v fail2ban-client &> /dev/null; then
        echo -e "${VERMELHO}Erro: Fail2Ban não está instalado no servidor.${NC}"
        sleep 2; return
    fi

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
        echo -e " [2] ⬅️  Voltar ao Menu Firewall"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha uma opção: " OP_BAN; echo ""

        case $OP_BAN in
            1) desbanir_ip ;; # Chama a função de desbanir já existente
            2) break ;;
            *) echo -e "${AMARELO}Opção inválida.${NC}"; sleep 1 ;;
        esac
    done
}

gerenciar_whitelist() {
    # Validação baseada no administrador cadastrado no sistema
    if [ "$USER_REAL" != "$ADM_USER" ]; then
        echo -e "${VERMELHO}Acesso negado! Apenas o administrador $ADM_USER gerencia a Whitelist.${NC}"
        sleep 2; return
    fi

    local ARQUIVO_WHITE="/etc/vps_protecao/whitelist.conf"
    [ ! -d "/etc/vps_protecao" ] && mkdir -p /etc/vps_protecao
    touch "$ARQUIVO_WHITE"

    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}GERENCIAR LISTA BRANCA (IP)${NC}"
        echo -e "  ADMINISTRADOR: ${AMARELO}$ADM_USER${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e " [1] Adicionar IP à Lista Branca"
        echo -e " [2] Ver IPs Protegidos"
        echo -e " [3] Remover IP da Lista Branca"
        echo -e " [4] Voltar ao Firewall"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha: " OP_W; echo ""

        case $OP_W in
            1)
                read -p " IP para proteger: " IP_W
                if [[ $IP_W =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    if grep -q "^$IP_W$" "$ARQUIVO_WHITE"; then
                        echo -e "${AMARELO}O IP $IP_W já está na lista!${NC}"
                    else
                        echo "$IP_W" >> "$ARQUIVO_WHITE"
                        sudo ufw allow from "$IP_W" to any > /dev/null 2>&1
                        echo -e "${VERDE}IP $IP_W protegido com sucesso!${NC}"
                    fi
                else
                    echo -e "${VERMELHO}Formato de IP inválido!${NC}"
                fi ;;
            2)
                echo -e "${AMARELO}Lista de IPs Protegidos:${NC}"
                [ -s "$ARQUIVO_WHITE" ] && cat -n "$ARQUIVO_WHITE" || echo "Lista vazia."
                read -p "Pressione enter..." ;;
            3)
                read -p " IP para remover a proteção: " IP_R
                if grep -q "^$IP_R$" "$ARQUIVO_WHITE"; then
                    sed -i "/^$IP_R$/d" "$ARQUIVO_WHITE"
                    sudo ufw delete allow from "$IP_R" to any > /dev/null 2>&1
                    echo -e "${AMARELO}Proteção removida para o IP $IP_R.${NC}"
                else
                    echo -e "${VERMELHO}IP não encontrado na lista.${NC}"
                fi ;;
            4) break ;;
        esac
        sleep 1
    done
}

banir_ip() {
    local ARQUIVO_WHITE="/etc/vps_protecao/whitelist.conf"
    
    echo -e "\n${AMARELO}---------------------------------------------------------------${NC}"
    read -p " Digite o IP que deseja BANIR (Bloqueio Total): " IP_ALVO
    
    # 1. Validação de formato de IP
    if [[ $IP_ALVO =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        
        # 2. VERIFICAÇÃO DE SEGURANÇA (WHITELIST)
        if [ -f "$ARQUIVO_WHITE" ] && grep -q "^$IP_ALVO$" "$ARQUIVO_WHITE"; then
            echo -e "${VERMELHO}❌ OPERAÇÃO BLOQUEADA!${NC}"
            echo -e "${AMARELO}O IP $IP_ALVO está na Lista Branca.${NC}"
            
            [ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf
            if [[ ! -z "$TOKEN" ]]; then
                MENSAGEM="🛡️ <b>AVISO:</b> Tentativa de banir IP Protegido: <code>$IP_ALVO</code>"
                curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
            fi
        else
            # 3. EXECUTA O BANIMENTO NAS 3 CAMADAS (INPUT, OUTPUT, FORWARD)
            echo -e "${VERMELHO}Bloqueando IP: $IP_ALVO em todas as camadas...${NC}"

            # Bloqueia a VPS de acessar o IP (Para o seu PING)
            sudo iptables -I OUTPUT -d "$IP_ALVO" -j DROP
            
            # Bloqueia o IP de tentar entrar na VPS (Segurança)
            sudo iptables -I INPUT -s "$IP_ALVO" -j DROP
            
            # Bloqueia Clientes VPN de acessarem esse IP (O Segredo)
            sudo iptables -I FORWARD -d "$IP_ALVO" -j DROP

            # Opcional: Mantém o UFW sincronizado
            sudo ufw insert 1 deny from "$IP_ALVO" to any > /dev/null 2>&1
            sudo ufw insert 1 deny out to "$IP_ALVO" > /dev/null 2>&1

            echo -e "${VERDE}✅ IP $IP_ALVO ISOLADO COM SUCESSO!${NC}"
            echo -e "${AMARELO}Teste agora o PING ou acesso pela VPN.${NC}"
        fi
    else
        echo -e "${VERMELHO}❌ Formato de IP inválido!${NC}"
    fi
    echo -e "${AMARELO}---------------------------------------------------------------${NC}"
    sleep 2
}

desbanir_ip() {
    echo -e "\n${AMARELO}---------------------------------------------------------------${NC}"
    read -p " Digite o IP para DESBANIR: " IP_DESBAN
    
    if [[ $IP_DESBAN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${AMARELO}Limpando regras para o IP: $IP_DESBAN...${NC}"

        # 1. Remove do IPTABLES (Usa -D para deletar)
        sudo iptables -D OUTPUT -d "$IP_DESBAN" -j DROP > /dev/null 2>&1
        sudo iptables -D INPUT -s "$IP_DESBAN" -j DROP > /dev/null 2>&1
        sudo iptables -D FORWARD -d "$IP_DESBAN" -j DROP > /dev/null 2>&1

        # 2. Remove do UFW (Sincronização)
        sudo ufw delete deny from "$IP_DESBAN" to any > /dev/null 2>&1
        sudo ufw delete deny out to "$IP_DESBAN" > /dev/null 2>&1

        echo -e "${VERDE}✅ O IP $IP_DESBAN foi liberado para o Servidor e VPN!${NC}"
    else
        echo -e "${VERMELHO}❌ Formato de IP inválido!${NC}"
    fi
    echo -e "${AMARELO}---------------------------------------------------------------${NC}"
    sleep 2
}

firewall() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERMELHO}🛡️  CENTRAL DE FIREWALL${NC}"
        echo -e "  ADMIN ATIVO: ${VERDE}$ADM_USER${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚫 Banir IP (Manual)"
        echo -e "  [2] ✅ Desbanir IP (Manual/Fail2Ban)"
        echo -e "  [3] 📋 Ver IPs Bloqueados (IPTables)"
        echo -e "  [4] 🚨 Monitorar Fail2Ban (Automático)"
        echo -e "  [5] ⚪ Gerenciar Whitelist (Lista Branca)"
        echo -e "  [6] 🕵️  Diagnóstico de Ataques (Ranking)"
        echo -e "  [0] ⬅️  Voltar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha: " OP_F; echo ""

        case $OP_F in
            1) banir_ip ;;
            2) desbanir_ip ;;
            3) clear; iptables -L INPUT -n | grep "DROP"; read -p "Pressione ENTER..." ;;
            4) monitora_banidos ;;
            5) gerenciar_whitelist ;;
            6) diagnostico_ataques ;;
            0) return ;; # Volta para o loop do menu principal
            *) echo -e "Opção inválida"; sleep 1 ;;
        esac
    done
}

ssh_config() {
    # Validação de permissão antes de qualquer ação
    verificar_permissao || return

    # --- ENVIO DE ALERTA PARA O TELEGRAM ---
    # Captura dados do acesso
    IP_USER=$(who am i | awk '{print $NF}' | tr -d '()')
    DATA_ATUAL=$(date +'%d/%m/%Y')
    HORA_ATUAL=$(date +'%H:%M:%S')

    # Tenta carregar as credenciais do Telegram
    [ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"

    if [[ ! -z "$TOKEN" ]]; then
        MENSAGEM="⚠️ <b>ACESSO AO SSH CONFIG</b>%0A<b>Usuário:</b> <code>$USER_REAL</code>%0A<b>IP:</b> <code>$IP_USER</code>%0A<b>Data:</b> $DATA_ATUAL%0A<b>Hora:</b> $HORA_ATUAL%0A%0A<i>Tentativa de alteração das configurações do SSH detectada!</i>"
        
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
             -d chat_id="$ID_CHAT" \
             -d text="$MENSAGEM" \
             -d parse_mode="HTML" > /dev/null
    fi

    # --- INÍCIO DO MENU SSH ---
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "  ADMINISTRADOR ATIVO: ${AMARELO}$ADM_USER${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH"
        echo -e "  [2] 👤 Permitir/Bloquear Login Root"
        echo -e "  [3] 🔑 Password Auth (Senha)"
        echo -e "  [4] 👢 Desconectar Usuário Ativo"
        echo -e "  [5] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Digite a opção: " OP; echo ""
        
        case $OP in
            1) 
                read -p " Nova Porta: " NP
                if [[ "$NP" =~ ^[0-9]+$ ]]; then
                    ufw allow "$NP"/tcp > /dev/null 2>&1
                    sed -i "/^Port /d" $SSH_CONF
                    echo "Port $NP" >> $SSH_CONF
                    systemctl restart ssh
                    echo -e "${VERDE}Porta alterada para $NP!${NC}"
                else
                    echo -e "${VERMELHO}Porta inválida!${NC}"
                fi
                sleep 2 ;;
            2) 
                echo -e "[1] Permitir [2] Bloquear"
                read -n 1 R; echo ""
                [ "$R" == "1" ] && VAL="yes" || VAL="no"
                sed -i "/^PermitRootLogin/d" $SSH_CONF
                echo "PermitRootLogin $VAL" >> $SSH_CONF
                systemctl restart ssh
                echo -e "${VERDE}PermitRootLogin definido como: $VAL${NC}"
                sleep 2 ;;
            3) 
                echo -e "[1] Ativar [2] Desativar"
                read -n 1 S; echo ""
                [ "$S" == "1" ] && VAL="yes" || VAL="no"
                sed -i "/^PasswordAuthentication/d" $SSH_CONF
                echo "PasswordAuthentication $VAL" >> $SSH_CONF
                systemctl restart ssh
                echo -e "${VERDE}Autenticação por senha: $VAL${NC}"
                sleep 2 ;;
            4) 
                clear
                echo -e "${AMARELO}--- USUÁRIOS CONECTADOS ---${NC}"
                who
                read -p " Usuário para expulsar: " U
                if [[ "$U" == "$USER_REAL" ]]; then
                    echo -e "${VERMELHO}Erro: Você não pode se auto-expulsar!${NC}"
                else
                    pkill -u "$U" -9
                    echo -e "${VERDE}Usuário $U desconectado.${NC}"
                fi
                sleep 2 ;;
            5) break ;;
        esac
    done
}

configurar_telegram() {
    verificar_permissao || return
    read -p "Token Bot: " tk; read -p "Chat ID: " cid
    echo -e "TOKEN=\"$tk\"\nID_CHAT=\"$cid\"" > "$TELEGRAM_CONF"
    echo "Salvo!"; sleep 2
}

restaura_seguranca() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "             ${AMARELO}RESTAURANDO SEGURANÇA E SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    # 1. Garante o Horário de Manaus (AMT)
    echo -e "${VERDE}[1/4]${NC} Sincronizando fuso horário (Manaus)..."
    sudo timedatectl set-timezone America/Manaus
    sudo timedatectl set-ntp true
    echo -e "      ${VERDE}✔ Horário do sistema atualizado: $(date)${NC}"

    # 2. Reset e Reconfiguração do Firewall (UFW)
    echo -e "${VERDE}[2/4]${NC} Resetando Firewall UFW..."
    echo "y" | sudo ufw reset > /dev/null
    sudo ufw default deny incoming > /dev/null
    sudo ufw default allow outgoing > /dev/null
    # Libera SSH e Portas de VPN/Dashboard
    sudo ufw allow ssh > /dev/null
    sudo ufw allow 1194/udp > /dev/null
    sudo ufw allow 80/tcp > /dev/null
    sudo ufw allow 443/tcp > /dev/null
    echo "y" | sudo ufw enable > /dev/null
    echo -e "      ${VERDE}✔ Firewall Restaurado e Protegido.${NC}"

    # 3. Reforço de Segurança no SSH
    echo -e "${VERDE}[3/4]${NC} Blindando acesso SSH..."
    sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sudo sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh > /dev/null
    echo -e "      ${VERDE}✔ SSH configurado para segurança máxima.${NC}"

    # 4. Verificação do Serviço Guardião
    echo -e "${VERDE}[4/4]${NC} Reiniciando Guardião..."
    if systemctl list-unit-files | grep -q guardiao.service; then
        sudo systemctl daemon-reload
        sudo systemctl enable guardiao.service > /dev/null
        sudo systemctl restart guardiao.service > /dev/null
        echo -e "      ${VERDE}✔ Guardião operando e monitorando.${NC}"
    else
        echo -e "      ${VERMELHO}✘ Alerta: Serviço Guardião não encontrado!${NC}"
    fi

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "    ${VERDE}✅ SISTEMA RESTAURADO E SINCRONIZADO!${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}

# --- ESTRUTURA DO MENU PRINCIPAL ---
while true; do
    # Atualiza dados em cada ciclo do menu
    IP_EXT=$(curl -s --max-time 2 ifconfig.me || echo "OFFLINE")
    PORTA_SSH=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}'); [ -z "$PORTA_SSH" ] && PORTA_SSH="22"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "  OPERADOR: ${AMARELO}$USER_REAL${NC} | ADMIN: ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  %-15s : ${AMARELO}%-20s${NC}\n" "IP SERVIDOR" "$IP_EXT"
    printf "  %-15s : ${AMARELO}%-20s${NC}\n" "PORTA SSH" "$PORTA_SSH"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📜 Logs do Sistema               [2] 🛡️  Firewall e Segurança"
    echo -e "  [3] ⚡ Testar Velocidade             [4] 🔑 SSH Config (Admin)"
    echo -e "  [5] 📉 VnStat (Consumo)              [6] 📢 Alerta Telegram (Admin)"
    echo -e "  [7] 🛡️ Restaurar Segurança Padrão    [0]🔄 Voltar ao Menu Inicial  "
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) firewall ;; 
        3) testa_velocidade ;;
        4) ssh_config ;;
        5) clear; vnstat -d; echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"; read -r ;;
        6) configurar_telegram ;;
        7) restaura_seguranca ;;
        0) 
            echo -e "${AMARELO}Saindo e recarregando menu.sh...${NC}"
            sleep 1
            # O comando exec substitui o processo atual pelo novo, reiniciando o script
            exec bash menu.sh 
            ;;
        *) 
            echo -e "${VERMELHO}Opção inválida!${NC}"
            sleep 1
            ;;
    esac
done
