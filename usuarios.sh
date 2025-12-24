#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos Profissional (Atualizado 24-12-2025)

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
    echo -e "${AMARELO} USUÁRIO             UID             PRIVILÉGIO${NC}"
    echo -e "---------------------------------------------------------------"
    
    while IFS=: read -r user pass uid gid info home shell; do
        if [[ "$home" == /home/* ]]; then
            if groups "$user" | grep -q "\bsudo\b"; then
                PRIV=$(echo -e "${VERMELHO}ADMIN (sudo)${NC}")
            else
                PRIV=$(echo -e "${VERDE}COMUM${NC}")
            fi
            printf " %-19s %-15s" "$user" "$uid"
            echo -e "$PRIV"
        fi
    done < /etc/passwd
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitorar_logados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}SESSÕES ATIVAS (IP E ATIVIDADE)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "${AMARELO}%-12s %-10s %-16s %-10s${NC}\n" "USUÁRIO" "TTY" "IP ORIGEM" "ATIVIDADE"
    echo -e "---------------------------------------------------------------"
    w -h | awk '{printf "%-12s %-10s %-16s %-10s\n", $1, $2, $3, $8}'
    echo -e "${AZUL}===============================================================${NC}"
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

adicionar_chave_ssh() {
    if [ "$USER_ATUAL" != "jutair" ]; then
        echo -e "${VERMELHO}Apenas o usuário jutair pode adicionar novas chaves.${NC}"
        sleep 2
        return
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "               ${VERDE}ADICIONAR CHAVE SSH PARA USUÁRIO${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    read -p "Nome do usuário: " USER_ALVO
    if ! id "$USER_ALVO" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário não existe.${NC}"
        sleep 2
        return
    fi

    read -p "Cole a chave pública SSH: " CHAVE
    [ -z "$CHAVE" ] && { echo -e "${AMARELO}Nenhuma chave informada.${NC}"; sleep 2; return; }

    SSH_DIR="/home/$USER_ALVO/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    echo "$CHAVE" >> "$AUTH_KEYS"
    chown -R "$USER_ALVO:$USER_ALVO" "$SSH_DIR"

    echo -e "${VERDE}Chave adicionada com sucesso para $USER_ALVO!${NC}"
    sleep 2
}

############################ MENU PRINCIPAL ############################

while true; do
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)

    if groups "$USER_ATUAL" | grep -q "\bsudo\b"; then
        STATUS_ROOT=$(echo -e "${VERDE}SIM (ROOT)${NC}")
    else
        STATUS_ROOT=$(echo -e "${VERMELHO}NÃO (LIMITADO)${NC}")
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
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
    echo -e "  [7] 🔑 Adicionar chave SSH (somente jutair)"
    echo -e "  [8] ⬅️  Retornar ao Menu Principal"
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
        7) adicionar_chave_ssh ;;
        8) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
