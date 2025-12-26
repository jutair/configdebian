#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos Profissional

# --- CONFIGURAÇÕES E CORES ---
DIR_PROT="/etc/vps_protecao"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Carrega configurações
[ -f "$DIR_PROT/telegram.conf" ] && source "$DIR_PROT/telegram.conf"
[ -f "$DIR_PROT/admin.conf" ] && source "$DIR_PROT/admin.conf"

# Detecção de Usuário Operador
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
        if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
            MENSAGEM="⚠️ <b>ALERTA DE SEGURANÇA:</b>%0AO usuário <code>$USER_ATUAL</code> tentou executar uma função restrita ao Admin!"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 2
        return 1
    fi
    return 0
}

############################ FUNÇÕES DE GESTÃO ############################

listar_usuarios_cadastrados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                📋 USUÁRIOS CADASTRADOS NO SISTEMA"
    echo -e "${AZUL}===============================================================${NC}"
    # Filtra apenas usuários reais (UID >= 1000)
    printf "${AMARELO}%-20s %-10s %-15s${NC}\n" "USUÁRIO" "UID" "STATUS"
    echo "---------------------------------------------------------------"
    while IFS=: read -r user pass uid gid info home shell; do
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            STATUS="${VERDE}ATIVO${NC}"
            [ "$user" == "$ADM_USER" ] && STATUS="${AZUL}ADMIN${NC}"
            printf "%-20s %-10s %-15b\n" "$user" "$uid" "$STATUS"
        fi
    done < /etc/passwd
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para voltar..." dummy
}

cadastrar_user() {
    read -p " Nome do novo usuário: " NU
    if id "$NU" &>/dev/null; then
        echo -e "${VERMELHO}Erro: Usuário já existe!${NC}"; sleep 2
    else
        read -s -p " Senha para $NU: " NS; echo ""
        useradd -m -s /bin/bash "$NU"
        echo "$NU:$NS" | chpasswd
        echo -e "${VERDE}✅ Usuário $NU criado com sucesso!${NC}"; sleep 2
    fi
}

remover_usuario() {
    verificar_admin || return
    read -p " Nome do usuário para remover: " UR
    if [[ "$UR" == "$ADM_USER" || "$UR" == "root" ]]; then 
        echo -e "${VERMELHO}❌ Erro: O usuário '$UR' é protegido pelo sistema!${NC}"; sleep 2
    elif id "$UR" &>/dev/null; then
        pkill -u "$UR" 2>/dev/null
        userdel -r "$UR" 2>/dev/null
        echo -e "${VERDE}✅ Usuário $UR removido com sucesso.${NC}"; sleep 2
    else 
        echo -e "${VERMELHO}Usuário não encontrado.${NC}"; sleep 2
    fi
}

alterar_senha_vps() {
    read -p " Alterar a senha de qual usuário? " USER_ALVO
    if [[ "$USER_ALVO" == "$ADM_USER" && "$USER_ATUAL" != "$ADM_USER" ]]; then
        verificar_admin; return
    fi
    if id "$USER_ALVO" &>/dev/null; then
        passwd "$USER_ALVO"
        echo -e "${VERDE}✅ Senha atualizada!${NC}"
    else
        echo -e "${VERMELHO}⚠️ Usuário não encontrado.${NC}"
    fi
    sleep 2
}

monitorar_logados() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                👁️  SESSÕES ATIVAS AGORA"
    echo -e "${AZUL}===============================================================${NC}"
    who
    echo "---------------------------------------------------------------"
}

############################ MENU PRINCIPAL ############################

while true; do
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
    echo -e "  [7] ⬅️  Sair"
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
               read -p "Qual nome?: " DERRUBAR
               if [[ "$DERRUBAR" == "$ADM_USER" || "$DERRUBAR" == "root" ]]; then
                   echo -e "${VERMELHO}❌ Ação negada! Não é possível derrubar o Administrador.${NC}"; sleep 2
               else
                   verificar_admin && { pkill -u "$DERRUBAR"; echo "Conexão encerrada."; sleep 2; }
               fi
           fi ;;
        7) exit 0 ;;
        *) sleep 1 ;;
    esac
done
