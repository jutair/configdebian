#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos Profissional
# Lista usuários atualizado com download e upload

# --- VARIÁVEIS E CORES ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
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

############################ FUNÇÕES DE LISTAGEM ############################
monitorar_logados() {
    clear
    echo -e "${AZUL}====================================================================${NC}"
    echo -e "              ${VERDE}SESSÕES ATIVAS — SSH E VPN (TEMPO REAL)${NC}"
    echo -e "${AZUL}====================================================================${NC}"
    printf "${AMARELO}%-15s %-6s %-18s %-15s %-12s${NC}\n" "USUÁRIO" "TIPO" "IP ORIGEM" "DOWNLOAD" "UPLOAD" "DESDE"
    echo -e "--------------------------------------------------------------------"

    # --- Sessões SSH ---
    who | while read -r user tty date time rest; do
        IP=$(echo "$rest" | awk '{print $1}' | tr -d '()')
        [[ -z "$IP" ]] && IP="Local"
        printf "👤 %-15s SSH   %-18s %-12s %-12s %-20s\n" "$user" "$IP" "-" "-" "$date $time"
    done

    # --- Sessões VPN ---
    STATUS_LOG="/var/log/openvpn/status.log"
    if [ -f "$STATUS_LOG" ]; then
        grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ usuario ipport _ _ recv sent conectado_em _; do
            IP=${ipport%%:*}  # remove porta
            RECV_MB=$(echo "scale=2; $recv/1048576" | bc)
            SENT_MB=$(echo "scale=2; $sent/1048576" | bc)
            printf "🔐 %-15s VPN   %-18s %-12s %-12s %-20s\n" "$usuario" "$IP" "${RECV_MB}MB" "${SENT_MB}MB" "$conectado_em"
        done
    fi

    echo -e "${AZUL}====================================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitorar_logados() {
    clear
    echo -e "${AZUL}====================================================================${NC}"
    echo -e "              ${VERDE}SESSÕES ATIVAS — SSH E VPN${NC}"
    echo -e "${AZUL}====================================================================${NC}"
    printf "${AMARELO}%-15s %-6s %-18s %-20s${NC}\n" "USUÁRIO" "TIPO" "IP ORIGEM" "DESDE"
    echo -e "--------------------------------------------------------------------"

    # --- Sessões SSH ---
    who | while read -r user tty date time rest; do
        IP=$(echo "$rest" | awk '{print $1}' | tr -d '()')
        [[ -z "$IP" ]] && IP="Local"
        printf "👤 %-15s SSH   %-18s %-20s\n" "$user" "$IP" "$date $time"
    done

    # --- Sessões VPN ---
    STATUS_LOG="/var/log/openvpn/status.log"
    if [ -f "$STATUS_LOG" ]; then
        grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ usuario ipport _ _ _ _ _ conectado_em _; do
            IP=${ipport%%:*}  # remove a porta
            # conectado_em contém só a data/hora
            printf "🔐 %-15s VPN   %-18s %-20s\n" "$usuario" "$IP" "$conectado_em"
        done
    fi

    echo -e "${AZUL}====================================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}


############################ FUNÇÕES DE GESTÃO ############################

cadastrar_user() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}CADASTRAR NOVO USUÁRIO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário: " NOME_USUARIO
    [ -z "$NOME_USUARIO" ] && return

    if id "$NOME_USUARIO" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário já existe!${NC}"; sleep 2; return
    fi

    useradd -m -s /bin/bash "$NOME_USUARIO"
    HOME_USER="/home/$NOME_USUARIO"
    mkdir -p "$HOME_USER/"{Backup,clientes_ovp,transfer}
    chown -R "$NOME_USUARIO:$NOME_USUARIO" "$HOME_USER"
    passwd "$NOME_USUARIO"
    echo -e "${VERDE}Usuário $NOME_USUARIO criado com sucesso!${NC}"
    sleep 2
}

############################ MENU PRINCIPAL ############################

while true; do
    # --- COLETA DE DADOS DO DASHBOARD ---
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)
    
    # Define a string de status com cores antes de entrar no printf
    if groups "$USER_ATUAL" | grep -q "\bsudo\b"; then
        STATUS_ROOT=$(echo -e "${VERDE}SIM (ROOT)${NC}")
    else
        STATUS_ROOT=$(echo -e "${VERMELHO}NÃO (LIMITADO)${NC}")
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Usamos echo -e para garantir que os escapes de cor sejam processados
    echo -e "  ${AZUL}USUÁRIO LOGADO      :${NC} ${AMARELO}$USER_ATUAL${NC}"
    echo -e "  ${AZUL}STATUS ROOT         :${NC} $STATUS_ROOT"
    echo -e "  ${AZUL}TOTAL CADASTRADOS   :${NC} ${AMARELO}$TOTAL_USERS${NC}"
    echo -e "  ${AZUL}SESSÕES ATIVAS      :${NC} ${VERDE}$LOGADOS_AGORA${NC}"
    
    echo -e "${AZUL}===============================================================${NC}"
    
    echo -e "  [1] 📋 Listar Todos os Usuários"
    echo -e "  [2] 👤 Cadastrar Novo Usuário"
    echo -e "  [3] 🚫 Remover Usuário"
    echo -e "  [4] 🔑 Alterar Senha"
    echo -e "  [5] 🆙 Promover a Root (Sudo)"
    echo -e "  [6] 👁️  Ver Sessões Ativas (Logados)"
    echo -e "  [7] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) cadastrar_user ;;
        3) 
            read -p " Nome para remover: " username
            if [ "$username" != "$USER_ATUAL" ]; then
                userdel -r "$username" 2>/dev/null && echo "Removido!" || echo "Erro!"; sleep 2
            fi ;;
        4) 
            read -p " Usuário para senha: " username
            passwd "$username"; sleep 2 ;;
        5) 
            read -p " Usuário para Sudo: " username
            usermod -aG sudo "$username" && echo "Promovido!"; sleep 2 ;;
        6) monitorar_logados ;;
        7) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
