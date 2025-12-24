#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos Profissional

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

listar_usuarios_cadastrados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS CADASTRADOS NO SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    # Cabeçalho da tabela
    echo -e "${AMARELO} USUÁRIO             UID             PRIVILÉGIO${NC}"
    echo -e "---------------------------------------------------------------"
    
    # Filtra usuários reais (com diretório em /home)
    while IFS=: read -r user pass uid gid info home shell; do
        if [[ "$home" == /home/* ]]; then
            # Verifica se pertence ao grupo sudo e define a label colorida
            if groups "$user" | grep -q "\bsudo\b"; then
                PRIV=$(echo -e "${VERMELHO}ADMIN (sudo)${NC}")
            else
                PRIV=$(echo -e "${VERDE}COMUM${NC}")
            fi
            
            # Alinhamento manual para evitar problemas com os códigos de cor
            # Usamos printf apenas para o nome e UID (que não têm cor) e echo para o privilégio
            printf " %-19s %-15s" "$user" "$uid"
            echo -e "$PRIV"
        fi
    done < /etc/passwd
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitorar_logados() {
    clear
    echo -e "${AZUL}====================================================================${NC}"
    echo -e "              ${VERDE}SESSÕES ATIVAS — SSH E VPN${NC}"
    echo -e "${AZUL}====================================================================${NC}"
    
    printf "${AMARELO}%-15s %-6s %-18s %-20s${NC}\n" "USUÁRIO" "TIPO" "IP ORIGEM" "DESDE"
    echo -e "--------------------------------------------------------------------"

    # --- SSH ---
    w -h | awk '{printf "👤 %-13s SSH   %-18s %-20s\n", $1, $3, $4}'

    # --- VPN ---
    if [ -f /var/log/openvpn/status.log ]; then
        awk '
        /^CLIENT_LIST/ {
            split($3,ip,":");
            printf "🔐 %-13s VPN   %-18s %-20s\n", $2, ip[1], $8
        }' /var/log/openvpn/status.log
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
