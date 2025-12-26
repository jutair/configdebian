#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos (Final 2025)

# --- CONFIGURAÇÕES E CORES ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Carrega configurações do Telegram se existirem
[ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"

# --- 1. DETECÇÃO DE USUÁRIO E ROOT ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
ADM_USER="jutair" 

if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C
trap '' SIGINT SIGTSTP

############################ FUNÇÕES DE LISTAGEM ############################

listar_usuarios_cadastrados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS CADASTRADOS NO SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "${AMARELO}%-19s %-15s %-15s${NC}\n" "USUÁRIO" "UID" "PRIVILÉGIO"
    echo -e "---------------------------------------------------------------"
    while IFS=: read -r user pass uid gid info home shell; do
        if [[ "$home" == /home/* ]]; then
            PRIV=$(groups "$user" | grep -q "\bsudo\b" && echo -e "${VERMELHO}ADMIN${NC}" || echo -e "${VERDE}COMUM${NC}")
            printf " %-18s %-15s %b\n" "$user" "$uid" "$PRIV"
        fi
    done < /etc/passwd
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..."
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
    read -p " Pressione ENTER para retornar..."
}

############################ FUNÇÕES DE GESTÃO ############################

cadastrar_user() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}CADASTRAR NOVO USUÁRIO (SSH + MENU)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário: " NOME_USUARIO
    [[ -z "$NOME_USUARIO" ]] && return
    if id "$NOME_USUARIO" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário já existe!${NC}"; sleep 2; return
    fi

    useradd -m -s /bin/bash "$NOME_USUARIO"
    HOME_USER="/home/$NOME_USUARIO"
    mkdir -p "$HOME_USER"/{Backup,clientes_ovp,transfer,.ssh}

    # --- AQUI ESTAVA O ERRO: CORREÇÃO COM 'EOF' ---
    cat << 'EOF' > "$HOME_USER/.bashrc"
[[ $- != *i* ]] && return
if [[ -n "$SSH_CONNECTION" ]]; then
    clear
    sudo -E bash /opt/configdebian/menu.sh
    exit
fi
EOF
    
    chmod 700 "$HOME_USER/.ssh"
    touch "$HOME_USER/.ssh/authorized_keys"
    chmod 600 "$HOME_USER/.ssh/authorized_keys"
    chown -R "$NOME_USUARIO:$NOME_USUARIO" "$HOME_USER"
    echo -e "${VERDE}✅ Usuário $NOME_USUARIO criado e travado no menu!${NC}"; sleep 2
}

gerenciar_banidos() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "             ${VERMELHO}🚫 GERENCIAR IPs BLOQUEADOS (UFW)${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        LISTA_BANS=$(ufw status | grep "DENY" | awk '{print $3}' | grep -v "Anywhere")
        if [ -z "$LISTA_BANS" ]; then
            echo -e "         ${VERDE}Nenhum IP bloqueado no momento.${NC}"
        else
            echo "$LISTA_BANS" | nl -w2 -s'. '
        fi
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🔓 Desbloquear IP | [2] ♻️ Limpar Tudo | [3] ⬅️ Voltar"
        read -n 1 -p " Escolha: " OP_BAN; echo ""
        case $OP_BAN in
            1) read -p " IP: " IP_REM; ufw delete deny from "$IP_REM" &>/dev/null; echo "Liberado!"; sleep 1 ;;
            2) ufw status numbered | grep "DENY" | awk -F"[][]" '{print $2}' | sort -rn | xargs -I{} ufw --force delete {} &>/dev/null; echo "Limpo!"; sleep 1 ;;
            3) return ;;
        esac
    done
}

alterar_senha_vps() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${AMARELO}GERENCIADOR DE SENHAS PROTEGIDO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Alterar a senha de qual usuário? " USER_ALVO
    if [[ "$USER_ALVO" == "$ADM_USER" && "$USER_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}❌ ACESSO NEGADO!${NC}"
        [[ -n "$TOKEN" ]] && curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="⚠️ Alerta: Tentativa de senha admin por $USER_ATUAL" > /dev/null
        sleep 3; return
    fi
    if id "$USER_ALVO" &>/dev/null; then
        passwd "$USER_ALVO"
        echo -e "${VERDE}✅ Sucesso!${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário inexistente.${NC}"
    fi
    sleep 2
}

############################ MENU PRINCIPAL ############################

while true; do
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)
    STATUS_ROOT=$(groups "$USER_ATUAL" | grep -q "\bsudo\b" && echo -e "${VERDE}SIM${NC}" || echo -e "${VERMELHO}NÃO${NC}")
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  Operador: ${AMARELO}$USER_ATUAL${NC} (${STATUS_ROOT}) | Ativos: ${VERDE}$LOGADOS_AGORA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📋 Listar Usuários     [2] 👤 Cadastrar Novo"
    echo -e "  [3] 🗑️  Remover Usuário    [4] 🔑 Alterar Senha"
    echo -e "  [5] 🆙 Promover a Root    [6] 👁️  Ver Logados"
    echo -e "  [7] 🚫 Gerenciar Bans     [8] 🔑 Chave SSH (Admin)"
    echo -e "  [9] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Opção: " OP; echo ""
    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) cadastrar_user ;;
        3) read -p "Nome: " UR
           if [[ "$UR" == "jutair" || "$UR" == "root" ]]; then echo "Protegido!"; sleep 2
           else pkill -u "$UR" 2>/dev/null; userdel -r "$UR" 2>/dev/null; echo "Removido."; sleep 2; fi ;;
        4) alterar_senha_vps ;;
        5) read -p "Usuário: " UP; usermod -aG sudo "$UP" && echo "Promovido."; sleep 2 ;;
        6) monitorar_logados ;;
        7) gerenciar_banidos ;;
        8) if [[ "$USER_ATUAL" == "$ADM_USER" ]]; then
                read -p "Usuário: " UA; read -p "Chave: " CK
                mkdir -p /home/$UA/.ssh && echo "$CK" >> /home/$UA/.ssh/authorized_keys
                chown -R $UA:$UA /home/$UA/.ssh && chmod 600 /home/$UA/.ssh/authorized_keys
                echo "Chave adicionada."; sleep 2
           else echo "Acesso negado."; sleep 2; fi ;;
        9) exit 0 ;;
        *) sleep 1 ;;
    esac
done
