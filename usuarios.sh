#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos Profissional (Versão Final Corrigida)

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
    printf "${AMARELO} %-19s %-15s %-15s${NC}\n" "USUÁRIO" "UID" "PRIVILÉGIO"
    echo -e "---------------------------------------------------------------"
    while IFS=: read -r user pass uid gid info home shell; do
        if [[ "$home" == /home/* ]]; then
            PRIV=$(groups "$user" | grep -q "\bsudo\b" && echo -e "${VERMELHO}ADMIN (sudo)${NC}" || echo -e "${VERDE}COMUM${NC}")
            printf " %-18s %-15s %b\n" "$user" "$uid" "$PRIV"
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

    # --- PRISÃO SSH: CORREÇÃO DEFINITIVA DAS ASPAS ---
    cat << 'EOF' > "$HOME_USER/.bashrc"
# ~/.bashrc - Menu automático VPS
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
    
    echo -e "${VERDE}✅ Usuário $NOME_USUARIO criado e configurado!${NC}"
    echo -e "${AMARELO}Acesso via Chave SSH com Menu Automático.${NC}"
    sleep 3
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
            echo -e "${AMARELO}IPs Restritos:${NC}"
            echo "$LISTA_BANS" | nl -w2 -s'. '
        fi
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🔓 Desbloquear um IP\n  [2] ♻️  Limpar Todos os Bloqueios\n  [3] ⬅️  Voltar"
        read -n 1 -p " Escolha: " OP_BAN; echo ""
        case $OP_BAN in
            1) read -p " Digite o IP para liberar: " IP_REM
               ufw delete deny from "$IP_REM" &>/dev/null
               echo -e "${VERDE}✅ IP $IP_REM liberado!${NC}"; sleep 1 ;;
            2) ufw status numbered | grep "DENY" | awk -F"[][]" '{print $2}' | sort -rn | xargs -I{} ufw --force delete {} &>/dev/null
               echo -e "${VERDE}✅ Firewall limpo e todos os IPs liberados!${NC}"; sleep 1 ;;
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
        if [ -n "$TOKEN" ]; then
            MENSAGEM="⚠️ <b>TENTATIVA DE INVASÃO:</b>%0AO usuário <code>$USER_ATUAL</code> tentou alterar a senha do administrador <code>$ADM_USER</code>!"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3; return
    fi

    if id "$USER_ALVO" &>/dev/null; then
        passwd "$USER_ALVO"
        echo -e "${VERDE}✅ Senha de '$USER_ALVO' atualizada!${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário '$USER_ALVO' não encontrado.${NC}"
    fi
    sleep 2
}

############################ MENU PRINCIPAL ############################

while true; do
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)
    STATUS_ROOT=$(groups "$USER_ATUAL" | grep -q "\bsudo\b" && echo -e "${VERDE}SIM (ROOT)${NC}" || echo -e "${VERMELHO}NÃO (LIMITADO)${NC}")

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  Operador: ${AMARELO}$USER_ATUAL${NC} (${STATUS_ROOT})"
    echo -e "  Cadastrados: ${AMARELO}$TOTAL_USERS${NC} | Sessões Ativas: ${VERDE}$LOGADOS_AGORA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📋 Listar Todos os Usuários"
    echo -e "  [2] 👤 Cadastrar Novo Usuário (SSH + Menu)"
    echo -e "  [3] 🗑️  Remover Usuário (Protegido)"
    echo -e "  [4] 🔑 Alterar Senha"
    echo -e "  [5] 🆙 Promover a Root (Sudo)"
    echo -e "  [6] 👁️  Ver Sessões Ativas (Logados)"
    echo -e "  [7] 🚫 Gerenciar IPs Banidos (UFW)"
    echo -e "  [8] 🔑 Adicionar Chave SSH (Admin)"
    echo -e "  [9] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    read -n 1 -p " Digite a opção: " OP; echo ""
    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) cadastrar_user ;;
        3) read -p "Nome do usuário para remover: " UR
           if [[ "$UR" == "jutair" || "$UR" == "root" ]]; then 
               echo -e "${VERMELHO}❌ Usuário '$UR' é protegido!${NC}"; sleep 2
           elif id "$UR" &>/dev/null; then
               pkill -u "$UR" 2>/dev/null; userdel -r "$UR" 2>/dev/null; echo -e "${VERDE}Removido.${NC}"; sleep 2
           else 
               echo -e "${VERMELHO}Usuário não existe.${NC}"; sleep 2
           fi ;;
        4) alterar_senha_vps ;;
        5) read -p "Usuário para promover: " UP
           if id "$UP" &>/dev/null; then
               usermod -aG sudo "$UP"
               echo "$UP ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
               echo -e "${VERDE}✅ $UP agora é Administrador!${NC}"
           else echo -e "${VERMELHO}Usuário não encontrado.${NC}"; fi; sleep 2 ;;
        6) monitorar_logados ;;
        7) gerenciar_banidos ;;
        8) if [ "$USER_ATUAL" == "$ADM_USER" ]; then
                read -p "Usuário alvo: " UA
                if id "$UA" &>/dev/null; then
                    read -p "Cole a Chave Pública SSH: " CK
                    [ -z "$CK" ] && continue
                    mkdir -p /home/$UA/.ssh
                    echo "$CK" >> /home/$UA/.ssh/authorized_keys
                    chown -R $UA:$UA /home/$UA/.ssh && chmod 600 /home/$UA/.ssh/authorized_keys
                    echo -e "${VERDE}Chave adicionada!${NC}"
                else echo -e "${VERMELHO}Usuário não existe.${NC}"; fi
           else echo -e "${VERMELHO}Ação restrita ao admin 'jutair'.${NC}"; fi; sleep 2 ;;
        9) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
