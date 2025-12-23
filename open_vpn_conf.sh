#!/bin/bash
# Identifica o usuário real (não o root) para as pastas
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores para o Menu
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
DESTINO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

# Verifica se o script está rodando como ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo! (sudo ./open_vpn_conf.sh)${SEM_COR}"
  exit 1
fi

# Cria a pasta de clientes se não existir
mkdir -p "$DESTINO"
chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO"

# --- FUNÇÕES ---
add_user() {
    clear
    echo "======================================"
    echo "      GERAR USUÁRIO (MODO EXPECT)     "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT_NAME
    [ -z "$CLIENT_NAME" ] && return

    echo -e "${AMARELO}Automatizando interação com o instalador...${SEM_COR}"

    # Entra na pasta de destino
    cd "$DESTINO" || exit

    # O script Expect simula você digitando
    /usr/bin/expect <<EOD
    set timeout 30
    spawn sudo "$INSTALLER_PATH" interactive
    
    expect "Select an option"
    send "1\r"
    
    expect "Client name:"
    send "$CLIENT_NAME\r"
    
    expect "Certificate validity"
    send "\r"
    
    # Adicione mais "expect" e "send" se o seu script fizer mais perguntas
    expect eof
EOD

    sleep 2

    # Verifica o local do arquivo
    if [ -f "${CLIENT_NAME}.ovpn" ]; then
        chown "$USER_ATUAL:$USER_ATUAL" "${CLIENT_NAME}.ovpn"
        chmod 644 "${CLIENT_NAME}.ovpn"
        echo -e "\n${VERDE}✅ SUCESSO! Arquivo: $DESTINO/${CLIENT_NAME}.ovpn${SEM_COR}"
    elif [ -f "/root/${CLIENT_NAME}.ovpn" ]; then
        mv "/root/${CLIENT_NAME}.ovpn" "$DESTINO/"
        chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO/${CLIENT_NAME}.ovpn"
        echo -e "\n${VERDE}✅ SUCESSO! Arquivo movido de /root.${SEM_COR}"
    else
        echo -e "\n${VERMELHO}❌ Erro: O arquivo não foi gerado.${SEM_COR}"
    fi

    cd - > /dev/null
    read -p "Pressione ENTER para voltar ao menu..." dummy
}
remove_user() {
    clear
    echo "===================================================="
    echo "            REMOVER USUÁRIO (REVOGAR)               "
    echo "===================================================="
    read -p "Nome do usuário para deletar: " CLIENT_NAME
    [ -z "$CLIENT_NAME" ] && return

    export MENU_OPTION="3"
    export CLIENT="$CLIENT_NAME"

    if sudo -E "$INSTALLER_PATH" > /dev/null; then
        rm -f "$DESTINO/$CLIENT_NAME.ovpn"
        echo -e "\n${VERDE}✅ Usuário $CLIENT_NAME removido com sucesso.${SEM_COR}"
    else
        echo -e "\n${VERMELHO}❌ Erro ao tentar remover o usuário.${SEM_COR}"
    fi
    read -p "Pressione ENTER..." dummy
}

listar_online() {
    clear
    echo "=========================================================================="
    echo "                 USUÁRIOS ONLINE E TRÁFEGO (MB)                           "
    echo "=========================================================================="
    
    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Arquivo de log não encontrado. Certifique-se que o serviço está rodando.${SEM_COR}"
    else
        echo -e "${VERDE}%-15s %-15s %-12s %-12s %-15s${SEM_COR}" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
        echo "--------------------------------------------------------------------------"
        
        # Filtra CLIENT_LIST do status log versão 2 (campos separados por TAB)
        grep "^CLIENT_LIST" "$STATUS_LOG" | while read -r line; do
            # No status version 2, os campos são separados por TAB (\t)
            USER=$(echo "$line" | cut -f2)
            IP=$(echo "$line" | cut -f3 | cut -d':' -f1)
            RECV_BYTES=$(echo "$line" | cut -f5)
            SENT_BYTES=$(echo "$line" | cut -f6)
            
            # Converte Bytes para MB
            RECV_MB=$(echo "scale=2; $RECV_BYTES/1048576" | bc)
            SENT_MB=$(echo "scale=2; $SENT_BYTES/1048576" | bc)
            DATA=$(echo "$line" | cut -f8)

            printf "%-15s %-15s %-12s %-12s %-15s\n" "$USER" "$IP" "${RECV_MB}MB" "${SENT_MB}MB" "$DATA"
        done
        
        if ! grep -q "^CLIENT_LIST" "$STATUS_LOG"; then
            echo -e "${AMARELO}Nenhum usuário conectado agora.${SEM_COR}"
        fi
    fi
    echo "=========================================================================="
    echo "Dica: Os dados de tráfego são atualizados a cada 5 segundos."
    read -p "Pressione ENTER para voltar..." dummy
}

menu_ovp() {
    while true; do
        clear
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e "               GERENCIADOR OPENVPN - DIGITALOCE                  "
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e " [1] Adicionar Usuário (Automático)"
        echo -e " [2] Remover Usuário (Revogar)"
        echo -e " [3] Listar Arquivos .ovpn Gerados"
        echo -e " [4] Ver Usuários Online & Consumo de Dados"
        echo -e " [5] Sair"
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        read -p "Escolha uma opção: " OPCAO
        case $OPCAO in
            1) add_user ;;
            2) remove_user ;;
            3) clear; echo "--- Arquivos Disponíveis em $DESTINO ---"; ls -1 "$DESTINO"; read -p "ENTER..." dummy ;;
            4) listar_online ;;
            5) exit 0 ;;
            *) echo -e "${VERMELHO}Opção inválida!${SEM_COR}"; sleep 1 ;;
        esac
    done
}

# Inicia o menu
menu_ovp
