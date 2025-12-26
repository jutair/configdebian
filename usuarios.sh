#!/bin/bash
# usuarios.sh - Gerenciador de Usuários e Acessos

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
    # Captura dados de quem está tentando acessar
    IP_USER=$(who am i | awk '{print $NF}' | tr -d '()')
    DATA_ATUAL=$(date +'%d/%m/%Y')
    HORA_ATUAL=$(date +'%H:%M:%S')

    if [[ "$USER_REAL" != "$ADM_USER" ]]; then
        clear
        echo -e "${VERMELHO}❌ AÇÃO NEGADA! Apenas o administrador '$ADM_USER' tem permissão.${NC}"
        
        # Tenta carregar as credenciais do Telegram se o arquivo existir
        [ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"

        if [[ -n "$TOKEN" && "$TOKEN" != "NAO_DEFINIDO" ]]; then
            MENSAGEM="⚠️ <b>Houve uma tentativa de alterar acesso de usuários do sistema!</b>%0A%0A<b>Usuário:</b> <code>$USER_REAL</code>%0A<b>Ip do usuário:</b> <code>$IP_USER</code>%0A<b>Data:</b> $DATA_ATUAL%0A<b>Hora:</b> $HORA_ATUAL"
            
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                 -d chat_id="$ID_CHAT" \
                 -d text="$MENSAGEM" \
                 -d parse_mode="HTML" > /dev/null
        fi
        
        sleep 3
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

adicionar_chave_ssh() {
    verificar_admin || return
    
    read -p " Nome do usuário que receberá a chave: " UA
    if id "$UA" &>/dev/null; then
        echo -e "${AMARELO}Cole a chave pública (começa com ssh-rsa ou ssh-ed25519):${NC}"
        read -r CK
        
        if [[ -z "$CK" ]]; then
            echo -e "${VERMELHO}Chave inválida!${NC}"; sleep 2; return
        fi

        # Define o caminho do diretório .ssh do usuário
        USER_HOME=$(eval echo ~$UA)
        mkdir -p "$USER_HOME/.ssh"
        
        # Adiciona a chave
        echo "$CK" >> "$USER_HOME/.ssh/authorized_keys"
        
        # Ajusta permissões (Crítico para o SSH aceitar)
        chown -R "$UA:$UA" "$USER_HOME/.ssh"
        chmod 700 "$USER_HOME/.ssh"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
        
        echo -e "${VERDE}✅ Chave SSH adicionada com sucesso para $UA!${NC}"
    else
        echo -e "${VERMELHO}Usuário não encontrado.${NC}"
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
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE USUÁRIOS E ACESSOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  OPERADOR ATUAL : ${AMARELO}$USER_ATUAL${NC} | ADMIN: ${VERDE}$ADM_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📋 Listar Todos os Usuários"
    echo -e "  [2] 👤 Cadastrar Novo Usuário (Admin Only)"
    echo -e "  [3] 🗑️  Remover Usuário (Admin Only)"
    echo -e "  [4] 🔑 Alterar Senha de Usuário"
    echo -e "  [5] 🆙 Promover a Root (Sudo)"
    echo -e "  [6] 👁️  Ver Sessões / Derrubar Usuário"
    echo -e "  [7] 🔑 Adicionar Chave SSH (Admin Only)"
    echo -e "  [8] ⬅️  Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    read -n 1 -p " Digite a opção: " OP; echo ""
    case $OP in
        1) listar_usuarios_cadastrados ;;
        2) verificar_admin && {
             read -p "Nome do novo usuário: " NU
             read -s -p "Senha para $NU: " NS; echo ""
             useradd -m -s /bin/bash "$NU"
             echo "$NU:$NS" | chpasswd
             echo -e "${VERDE}Usuário criado!${NC}"; sleep 2
           } ;;
        3) verificar_admin && {
             read -p "Remover qual usuário?: " UR
             if [[ "$UR" != "$ADM_USER" ]]; then
                userdel -r "$UR" && echo "Removido." || echo "Erro."
             else
                echo "Não pode remover o admin.";
             fi
             sleep 2
           } ;;
        4) # Alterar Senha
           read -p "Alterar senha de: " UA
           if [[ "$UA" == "$ADM_USER" ]]; then verificar_admin || continue; fi
           passwd "$UA" && echo "Sucesso."; sleep 2 ;;
        5) verificar_admin && { read -p "Usuário: " UP; usermod -aG sudo "$UP"; sleep 2; } ;;
        6) monitorar_logados 
           read -p "Deseja derrubar um usuário? (s/n): " RESP
           if [[ "$RESP" == "s" ]]; then
               read -p "Qual nome?: " DERRUBAR
               if [[ "$DERRUBAR" == "$ADM_USER" || "$DERRUBAR" == "root" ]]; then
                   echo -e "${VERMELHO}❌ Proibido derrubar Administrador!${NC}"; sleep 2
               else
                   verificar_admin && { pkill -u "$DERRUBAR"; sleep 2; }
               fi
           fi ;;
        7) adicionar_chave_ssh ;;
        8) exit 0 ;;
        *) sleep 1 ;;
    esac
done
