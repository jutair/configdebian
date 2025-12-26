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
firewall() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERMELHO}🛡️  GESTÃO DE FIREWALL (IP)${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚫 Banir IP (Manual/Total)"
        echo -e "  [2] ✅ Desbanir IP (Manual)"
        echo -e "  [3] 📋 Listar IPs Bloqueados (IPTables)"
        echo -e "  [4] 🚨 Monitorar Fail2Ban (Automático)"
        echo -e "  [5] ⚪ Gerenciar Whitelist (Lista Branca)" # <--- Integrado aqui
        echo -e "  [6] 🕵️  Diagnóstico de Ataques"
        echo -e "  [7] ⬅️  Voltar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Escolha uma opção: " OP_FIRE; echo ""

        case $OP_FIRE in
            1) banir_ip ;;
            2) desbanir_ip ;;
            3) 
                clear
                echo -e "${VERMELHO}--- IPs BLOQUEADOS NO IPTABLES ---${NC}"
                sudo iptables -L INPUT -n | grep "DROP"
                read -p "ENTER para voltar..." d ;;
            4) monitora_banidos ;;
            5) gerenciar_whitelist ;; # Chama a função acima
            6) diagnostico_ataques ;;
            7) return ;;
            *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
        esac
    done
}


configurar_telegram() {
    verificar_permissao || return
    read -p "Token Bot: " tk; read -p "Chat ID: " cid
    echo -e "TOKEN=\"$tk\"\nID_CHAT=\"$cid\"" > "$TELEGRAM_CONF"
    echo "Salvo!"; sleep 2
}

# --- ESTRUTURA DO MENU PRINCIPAL ---
while true; do
    # Atualiza dados em cada ciclo do menu para refletir mudanças em tempo real
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
    echo -e "  [1] 📜 Logs do Sistema         [5] 🛡️  Firewall e Segurança"
    echo -e "  [2] ⚡ Testar Velocidade       [6] 🔑 SSH Config (Admin)"
    echo -e "  [3] 📉 VnStat (Consumo)        [7] 📢 Alerta Telegram (Admin)"
    echo -e "  [4] 🔄 Reiniciar Menu          [0] 🚪 Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) visualizar_logs ;;
        2) testa_velocidade ;;
        3) clear; vnstat -d; echo -e "\n${AMARELO}Pressione ENTER para voltar...${NC}"; read -r ;;
        4) 
            echo -e "${AMARELO}A reiniciar o menu principal...${NC}"
            sleep 1
            continue 
            ;;
        5) firewall ;; # Centraliza Banir, Desbanir, Monitorar e Whitelist
        6) ssh_config ;;
        7) configurar_telegram ;;
        0) break ;; # Sai do loop caso o terminal não esteja travado por trap
        *) 
            echo -e "${VERMELHO}Opção inválida!${NC}"
            sleep 1
            ;;
    esac
done
