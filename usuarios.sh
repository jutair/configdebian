#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos com Verificação de Admin Real

# --- CONFIGURAÇÕES E CORES ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Carrega configurações (Telegram e definição de ADM_USER)
# O arquivo admin.conf deve conter: ADM_USER="seu_nome"
[ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
[ -f "$DIR_PROT/admin.conf" ] && source "$DIR_PROT/admin.conf"

# Caso o arquivo não exista, define um padrão de segurança ou busca do sistema
[[ -z "$ADM_USER" ]] && ADM_USER="jutair"

# --- 1. DETECÇÃO DE USUÁRIO OPERADOR ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})

if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

trap '' SIGINT SIGTSTP

############################ FUNÇÕES DE VALIDAÇÃO ############################

verificar_admin() {
    if [[ "$USER_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}❌ AÇÃO NEGADA! Apenas o administrador '$ADM_USER' tem permissão.${NC}"
        if [ -n "$TOKEN" ]; then
            MENSAGEM="⚠️ <b>ALERTA DE SEGURANÇA:</b>%0AO usuário <code>$USER_ATUAL</code> tentou executar uma função restrita ao Admin!"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 2
        return 1 # Falso
    fi
    return 0 # Verdadeiro
}

############################ FUNÇÕES DE GESTÃO ############################

remover_usuario() {
    verificar_admin || return
    read -p "Nome do usuário para remover: " UR
    if [[ "$UR" == "$ADM_USER" || "$UR" == "root" ]]; then 
        echo -e "${VERMELHO}❌ Erro: O usuário '$UR' é protegido pelo sistema!${NC}"; sleep 2
    elif id "$UR" &>/dev/null; then
        pkill -u "$UR" 2>/dev/null
        userdel -r "$UR" 2>/dev/null
        echo -e "${VERDE}✅ Usuário $UR removido e processos encerrados.${NC}"; sleep 2
    else 
        echo -e "${VERMELHO}Usuário não encontrado.${NC}"; sleep 2
    fi
}

alterar_senha_vps() {
    read -p " Alterar a senha de qual usuário? " USER_ALVO
    
    # Se tentar alterar a senha do ADMIN e não for o ADMIN
    if [[ "$USER_ALVO" == "$ADM_USER" && "$USER_ATUAL" != "$ADM_USER" ]]; then
        verificar_admin
        return
    fi

    if id "$USER_ALVO" &>/dev/null; then
        passwd "$USER_ALVO"
        echo -e "${VERDE}✅ Senha atualizada!${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário não encontrado.${NC}"
    fi
    sleep 2
}

# ... (Funções de listagem e cadastro permanecem iguais ao código anterior) ...

############################ MENU PRINCIPAL ############################

while true; do
    TOTAL_USERS=$(grep -c "/home" /etc/passwd)
    LOGADOS_AGORA=$(who | wc -l)
    STATUS_ROOT=$(groups "$USER_ATUAL" | grep -q "\bsudo\b" && echo -e "${VERDE}SIM (ROOT)${NC}" || echo -e "${VERMELHO}NÃO${NC}")

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  OPERADOR ATUAL : ${AMARELO}$USER_ATUAL${NC} | ADMIN: ${VERDE}$ADM_USER${NC}"
    echo -e "  STATUS PRIVILEGIO: $STATUS_ROOT"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📋 Listar Todos os Usuários"
    echo -e "  [2] 👤 Cadastrar Novo Usuário"
    echo -e "  [3] 🗑️  Remover Usuário (RESTRITO)"
    echo -e "  [4] 🔑 Alterar Senha (RESTRITO AO ADMIN)"
    echo -e "  [5] 🆙 Promover a Root (Sudo)"
    echo -e "  [6] 👁️  Ver Sessões / Derrubar Usuário"
    echo -e "  [7] 🚫 Gerenciar IPs Banidos (UFW)"
    echo -e "  [8] 🔑 Adicionar Chave SSH (RESTRITO)"
    echo -e "  [9] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    read -n 1 -p " Digite a opção: " OP; echo ""
    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) cadastrar_user ;;
        3) remover_usuario ;;
        4) alterar_senha_vps ;;
        5) verificar_admin && { 
               read -p "Usuário: " UP; usermod -aG sudo "$UP"
               echo -e "${VERDE}Promovido!${NC}"; sleep 2; 
           } ;;
        6) monitorar_logados 
           read -p "Deseja derrubar um usuário logado? (s/n): " RESP
           if [[ "$RESP" == "s" ]]; then
               verificar_admin && { read -p "Qual nome?: " DERRUBAR; pkill -u "$DERRUBAR"; echo "Conexão encerrada."; sleep 2; }
           fi ;;
        7) gerenciar_banidos ;;
        8) # Adicionar Chave SSH
           if verificar_admin; then
                read -p "Usuário alvo: " UA
                read -p "Cole a Chave Pública SSH: " CK
                if id "$UA" &>/dev/null && [ -n "$CK" ]; then
                    mkdir -p /home/$UA/.ssh
                    echo "$CK" >> /home/$UA/.ssh/authorized_keys
                    chown -R $UA:$UA /home/$UA/.ssh && chmod 600 /home/$UA/.ssh/authorized_keys
                    echo -e "${VERDE}Chave autorizada!${NC}"; sleep 2
                fi
           fi ;;
        9) exit 0 ;;
        *) sleep 1 ;;
    esac
done
