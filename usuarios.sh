#!/bin/bash
# usuarios.sh - Gerenciador de Usuários Dinâmico (Versão Blindada 26/12/2025)

# --- CONFIGURAÇÕES DE DIRETÓRIOS E IDENTIDADE ---
DIR_PROT="/etc/vps_protecao"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Carrega o Administrador Oficial
if [ -f "$DIR_PROT/config.conf" ]; then
    source "$DIR_PROT/config.conf"
else
    ADM_USER="root"
fi

# Detecta quem está executando o script agora
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_ATUAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_ATUAL=$(whoami)
fi

# --- 🛡️ SEGURANÇA MÁXIMA ---
# Bloqueia Ctrl+C, Ctrl+Z e saídas inesperadas para o terminal
fechar_por_seguranca() {
    if [ "$USER_ATUAL" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ ACESSO NEGADO! Encerrando sessão...${NC}"
        pkill -u "$USER_ATUAL" -9
        exit 1
    fi
}
trap fechar_por_seguranca SIGINT SIGTSTP SIGQUIT

# Verifica ROOT para execução
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Este script deve rodar como root/sudo!${NC}"
  sleep 2
  exit 1
fi

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

    # Cria usuário com shell bash
    useradd -m -s /bin/bash "$NOME_USUARIO"
    HOME_USER="/home/$NOME_USUARIO"

    # Configura o .bashrc para abrir o menu em modo PRISÃO (exec)
    cat << 'EOF' > "$HOME_USER/.bashrc"
[[ $- != *i* ]] && return
if [[ -n "$SSH_CONNECTION" ]]; then
    clear
    exec sudo -E bash /opt/configdebian/menu.sh
fi
EOF
    chown "$NOME_USUARIO:$NOME_USUARIO" "$HOME_USER/.bashrc"
    
    echo -e "${VERDE}✅ Usuário $NOME_USUARIO criado com sucesso!${NC}"
    echo -e "${AMARELO}O menu iniciará automaticamente e bloqueará o shell.${NC}"
    sleep 2
}

adicionar_chave_ssh() {
    # Somente o administrador definido pode gerenciar chaves
    if [ "$USER_ATUAL" != "$ADM_USER" ]; then
        echo -e "${VERMELHO}❌ Apenas o Administrador ($ADM_USER) pode gerenciar chaves!${NC}"
        sleep 2; return
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}ADICIONAR CHAVE SSH${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário alvo: " USER_ALVO
    if ! id "$USER_ALVO" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário não existe.${NC}"; sleep 2; return
    fi

    read -p " Cole a chave pública SSH: " CHAVE
    [ -z "$CHAVE" ] && return

    SSH_DIR="/home/$USER_ALVO/.ssh"
    mkdir -p "$SSH_DIR"
    echo "$CHAVE" >> "$SSH_DIR/authorized_keys"
    chmod 700 "$SSH_DIR" && chmod 600 "$SSH_DIR/authorized_keys"
    chown -R "$USER_ALVO:$USER_ALVO" "$SSH_DIR"

    echo -e "${VERDE}✅ Chave adicionada para $USER_ALVO!${NC}"; sleep 2
}

remover_usuario_protegido() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERMELHO}REMOVER USUÁRIO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário para remover: " USER_REM

    # Proteção de contas do sistema
    if [[ "$USER_REM" == "$ADM_USER" || "$USER_REM" == "root" || "$USER_REM" == "$OPE_USER" ]]; then
        echo -e "${VERMELHO}❌ ERRO: O usuário '$USER_REM' está protegido pelo sistema!${NC}"
        sleep 3; return
    fi

    if id "$USER_REM" &>/dev/null; then
        pkill -u "$USER_REM" -9 2>/dev/null || true
        userdel -r "$USER_REM"
        echo -e "${VERDE}✅ Usuário $USER_REM removido permanentemente.${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário inexistente.${NC}"
    fi
    sleep 2
}

alterar_senha_vps() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${AMARELO}ALTERAR SENHA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Alterar a senha de qual usuário? " USER_ALVO

    # Se tentar mudar a senha do admin sem ser o admin
    if [[ "$USER_ALVO" == "$ADM_USER" && "$USER_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}❌ ACESSO NEGADO!${NC}"
        # Alerta opcional no telegram (source /etc/vps_protecao/telegram.conf...)
        sleep 3; return
    fi

    if id "$USER_ALVO" &>/dev/null; then
        passwd "$USER_ALVO"
        echo -e "${VERDE}✅ Senha atualizada.${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário não encontrado.${NC}"
    fi
    sleep 2
}

# ... (Funções listar_usuarios_cadastrados, monitorar_logados e gerenciar_banidos permanecem similares) ...
# [Mantenha-as como no seu original, apenas garantindo o uso das variáveis de cores]

############################ MENU PRINCIPAL USUÁRIOS ############################

while true; do
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  ${AZUL}OPERADOR ATUAL:${NC} ${AMARELO}$USER_ATUAL${NC}"
    echo -e "  ${AZUL}ADMINISTRADOR :${NC} ${VERDE}$ADM_USER${NC}"
    echo -e "  ${AZUL}LOGADOS AGORA :${NC} ${VERDE}$LOGADOS_AGORA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📋 Listar Usuários"
    echo -e "  [2] 👤 Cadastrar Usuário"
    echo -e "  [3] 🗑️  Remover Usuário"
    echo -e "  [4] 🔑 Alterar Senha"
    echo -e "  [5] 🆙 Promover a Admin"
    echo -e "  [6] 👁️  Sessões Ativas"
    echo -e "  [7] 🚫 IPs Banidos"
    echo -e "  [8] 🔑 Adicionar Chave SSH (Apenas $ADM_USER)"
    echo -e "  [9] ⬅️  Voltar ao Menu"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    read -n 1 -p " Escolha: " OP; echo ""
    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) cadastrar_user ;;
        3) remover_usuario_protegido ;;
        4) alterar_senha_vps ;;
        5) 
            if [ "$USER_ATUAL" == "$ADM_USER" ]; then
                read -p "Usuário para promover: " U_P
                usermod -aG sudo "$U_P"
                echo "$U_P ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-vpn-users
            else
                echo -e "${VERMELHO}Ação restrita ao Administrador.${NC}"; sleep 2
            fi
            ;;
        6) monitorar_logados ;;
        7) gerenciar_banidos ;;
        8) adicionar_chave_ssh ;;
        9) exit 0 ;; # Retorna ao menu.sh (que está com exec)
        *) sleep 1 ;;
    esac
done
