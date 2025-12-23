#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos

# --- VARIÁVEIS E CORES ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)

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

############################ FUNÇÕES DE APOIO ############################

monitorar_logados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS CONECTADOS AGORA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    # Mostra Usuário, Terminal, IP de Origem e o que está executando
    printf "${AMARELO}%-12s %-10s %-16s %-10s${NC}\n" "USUÁRIO" "TTY" "IP ORIGEM" "ATIVIDADE"
    echo -e "---------------------------------------------------------------"
    w -h | awk '{printf "%-12s %-10s %-16s %-10s\n", $1, $2, $3, $8}'
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

cadastrar_user() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}CADASTRO DE NOVO USUÁRIO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Digite o nome do novo usuário: " NOME_USUARIO

    if id "$NOME_USUARIO" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário já existe!${NC}"
        sleep 2; return
    fi

    # 1. Cria usuário
    useradd -m -s /bin/bash "$NOME_USUARIO"
    HOME_USER="/home/$NOME_USUARIO"

    # 2. Configura SSH
    mkdir -p "$HOME_USER/.ssh"
    [ -f /root/.ssh/authorized_keys ] && cp /root/.ssh/authorized_keys "$HOME_USER/.ssh/authorized_keys"

    # 3. Pastas Padrão e Backup
    mkdir -p "$HOME_USER/"{Backup,clientes_ovp,transfer}
    [ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config "$HOME_USER/Backup/sshd_config.bak"

    # 4. Download Scripts (Ajustado para o seu repositório)
    echo -e "${AMARELO}Baixando ferramentas de gerenciamento...${NC}"
    wget -qO "$HOME_USER/main.zip" "https://github.com/jutair/configdebian/archive/refs/heads/main.zip"
    unzip -qo "$HOME_USER/main.zip" -d "$HOME_USER/"
    rm "$HOME_USER/main.zip"

    # 5. Permissões
    chown -R "$NOME_USUARIO:$NOME_USUARIO" "$HOME_USER"
    chmod 700 "$HOME_USER/.ssh"
    chmod -R +x "$HOME_USER/configdebian-main"/*.sh 2>/dev/null

    # 6. Senha e Sudo
    passwd "$NOME_USUARIO"
    
    echo -e "\n${AZUL}Deseja promover ${AMARELO}$NOME_USUARIO${AZUL} a ROOT (Sudo)? [s/n]${NC}"
    read -n 1 USEROOT
    if [[ $USEROOT =~ ^[sS]$ ]]; then
        usermod -aG sudo "$NOME_USUARIO"
        echo -e "\n${VERDE}Usuário promovido!${NC}"
    else
        echo "$NOME_USUARIO ALL=(ALL) NOPASSWD: /home/$NOME_USUARIO/configdebian-main/*.sh" >> /etc/sudoers
    fi
    sleep 2
}

############################ MENU PRINCIPAL ############################

while true; do
    # --- COLETA DE DADOS DO DASHBOARD ---
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)
    
    # Verifica se o usuário atual tem Sudo
    if groups "$USER_ATUAL" | grep -q "\bsudo\b"; then
        STATUS_ROOT="${VERDE}SIM (ROOT)${NC}"
    else
        STATUS_ROOT="${VERMELHO}NÃO (LIMITADO)${NC}"
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  ${AZUL}%-20s :${NC} ${AMARELO}%-20s${NC}\n" "USUÁRIO ATUAL" "$USER_ATUAL"
    printf "  ${AZUL}%-20s :${NC} %-20s\n" "PRIVILÉGIOS" "$STATUS_ROOT"
    printf "  ${AZUL}%-20s :${NC} ${AMARELO}%-20s${NC}\n" "CADASTRADOS (Home)" "$TOTAL_USERS"
    printf "  ${AZUL}%-20s :${NC} ${VERDE}%-20s${NC}\n" "LOGADOS AGORA" "$LOGADOS_AGORA"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Lista rápida de usuários (Home)
    echo -ne "  ${AZUL}USUÁRIOS:${NC} "
    ls /home | tr '\n' ' ' | sed 's/ $//'
    echo -e "\n${AZUL}---------------------------------------------------------------${NC}"
    
    echo -e "  [1] 👤 Cadastrar Novo Usuário"
    echo -e "  [2] 🚫 Remover Usuário"
    echo -e "  [3] 🔑 Alterar Senha"
    echo -e "  [4] 🆙 Promover a Root (Sudo)"
    echo -e "  [5] 👁️  Ver Quem está Logado e Onde"
    echo -e "  [6] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) cadastrar_user ;;
        2) 
            clear
            echo -e "Digite o nome para ${VERMELHO}REMOVER${NC}: "
            read username
            if [ "$username" != "$USER_ATUAL" ] && [ "$username" != "root" ]; then
                userdel -r "$username" 2>/dev/null && echo "Removido!" || echo "Erro!"
            else
                echo -e "${VERMELHO}Ação proibida!${NC}"
            fi
            sleep 2 ;;
        3) 
            read -p "Usuário para nova senha: " username
            passwd "$username"; sleep 2 ;;
        4) 
            read -p "Usuário para promover: " username
            usermod -aG sudo "$username" && echo -e "${VERDE}Promovido!${NC}" || echo "Erro!"; sleep 2 ;;
        5) monitorar_logados ;;
        6) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
