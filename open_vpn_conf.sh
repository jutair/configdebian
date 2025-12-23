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
SCRIPT_REDE="/home/$USER_ATUAL/configdebian-main/gerencia_rede.sh"

# Verifica se o script está rodando como ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# Instala dependências se faltarem
if ! command -v speedtest-cli &> /dev/null || ! command -v vnstat &> /dev/null || ! command -v expect &> /dev/null; then
    echo -e "${AMARELO}Instalando ferramentas necessárias...${SEM_COR}"
    apt update && apt install speedtest-cli vnstat expect bc -y
fi

# Cria a pasta de clientes se não existir
mkdir -p "$DESTINO"
chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO"

# --- FUNÇÕES ---

add_user() {
    clear
    echo "======================================"
    echo "      GERAR USUÁRIO (MODO ENTER)      "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT_NAME
    [ -z "$CLIENT_NAME" ] && return

    echo -e "${AMARELO}O robô está processando os campos automáticos...${SEM_COR}"

    /usr/bin/expect <<EOD
    set timeout 60
    spawn sudo "$INSTALLER_PATH" interactive
    expect "Select an option"
    sleep 1
    send "1\r"
    expect "Client name:"
    sleep 1
    send "$CLIENT_NAME\r"
    expect "Certificate validity"
    sleep 1
    send "\r"
    expect "Select an option"
    sleep 1
    send "\r"
    expect eof
EOD

    sleep 2
    ARQUIVO_FINAL=$(find /root /home -name "${CLIENT_NAME}.ovpn" -mmin -2 2>/dev/null | head -n 1)

    if [ -n "$ARQUIVO_FINAL" ] && [ -f "$ARQUIVO_FINAL" ]; then
        sudo mv "$ARQUIVO_FINAL" "$DESTINO/${CLIENT_NAME}.ovpn"
        sudo chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO/${CLIENT_NAME}.ovpn"
        sudo chmod 644 "$DESTINO/${CLIENT_NAME}.ovpn"
        echo -e "\n${VERDE}✅ SUCESSO! Arquivo salvo em: $DESTINO/${CLIENT_NAME}.ovpn${SEM_COR}"
    else
        echo -e "\n${VERMELHO}❌ Erro: O arquivo não foi localizado.${SEM_COR}"
    fi
    read -p "Pressione ENTER para voltar..." dummy
}

remove_user() {
    clear
    echo "======================================"
    echo "        REMOVER USUÁRIO (REVOKE)      "
    echo "======================================"
    echo -e "${AMARELO}Consultando lista de clientes atuais...${SEM_COR}"
    printf "3\n" | sudo "$INSTALLER_PATH" interactive | sed -n '/Select the existing/,/Select one client/p'
    
    echo ""
    read -p "Digite o NÚMERO do cliente que deseja remover: " NUM_CLIENTE
    [ -z "$NUM_CLIENTE" ] && return

    /usr/bin/expect <<EOD
    set timeout 60
    spawn sudo "$INSTALLER_PATH" interactive
    expect "Select an option"
    send "3\r"
    expect "Select one client"
    send "$NUM_CLIENTE\r"
    expect {
        "Continue?" { send "\r"; exp_continue }
        "Confirm"  { send "\r"; exp_continue }
        eof
    }
EOD
    echo -e "\n${VERDE}✅ Revogação concluída!${SEM_COR}"
    read -p "Pressione ENTER para voltar ao menu..." dummy
}

listar_online() {
    clear
    echo "=========================================================================="
    echo "                 USUÁRIOS ONLINE E TRÁFEGO (MB)                           "
    echo "=========================================================================="
    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Arquivo de log não encontrado em: $STATUS_LOG${SEM_COR}"
    else
        printf "${VERDE}%-15s %-15s %-12s %-12s %-15s${SEM_COR}\n" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
        echo "--------------------------------------------------------------------------"
        grep "^CLIENT_LIST" "$STATUS_LOG" | while read -r line; do
            if [[ "$line" == *","* ]]; then SEP=","; else SEP="\t"; fi
            USER=$(echo "$line" | cut -d"$SEP" -f2)
            IP=$(echo "$line" | cut -d"$SEP" -f3 | cut -d':' -f1)
            RECV_BYTES=$(echo "$line" | cut -d"$SEP" -f5)
            SENT_BYTES=$(echo "$line" | cut -d"$SEP" -f6)
            DATA=$(echo "$line" | cut -d"$SEP" -f8)
            RECV_MB=$(echo "scale=2; $RECV_BYTES/1048576" | bc)
            SENT_MB=$(echo "scale=2; $SENT_BYTES/1048576" | bc)
            printf "%-15s %-15s %-12s %-12s %-15s\n" "$USER" "$IP" "${RECV_MB}MB" "${SENT_MB}MB" "$DATA"
        done
        if ! grep -q "^CLIENT_LIST" "$STATUS_LOG"; then
            echo -e "${AMARELO}Nenhum usuário conectado no momento.${SEM_COR}"
        fi
    fi
    read -p "Pressione ENTER para voltar..." dummy
}

teste_velocidade() {
    clear
    echo "Iniciando Speedtest... Aguarde..."
    speedtest-cli --share
    read -p "Pressione ENTER para voltar..." dummy
}

trafego_acumulado() {
    while true; do
        clear
        echo " [1] Diário | [2] Mensal | [3] Anual | [4] Voltar"
        read -p "Escolha: " PERIODO
        IFACE="eth0"; ip link show tun0 > /dev/null 2>&1 && IFACE="tun0"
        case $PERIODO in
            1) vnstat -i "$IFACE" -d; read -p "ENTER..." d ;;
            2) vnstat -i "$IFACE" -m; read -p "ENTER..." d ;;
            3) vnstat -i "$IFACE" -y; read -p "ENTER..." d ;;
            4) return ;;
        esac
    done
}

chamar_seguranca() {
    [ -f "$SCRIPT_REDE" ] && bash "$SCRIPT_REDE" || echo "Script não encontrado!"
}

menu_ovp() {
    while true; do
        clear
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e "                GERENCIADOR OPENVPN - DIGITALOCE                 "
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e " [1] Adicionar Usuário (Robô)     [5] Speedtest"
        echo -e " [2] Remover Usuário (Revogar)    [6] VnStat (Tráfego)"
        echo -e " [3] Listar Arquivos .ovpn        [7] Rede & Segurança"
        echo -e " [4] Usuários Online              [8] Sair"
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        read -p "Escolha: " OPCAO
        case $OPCAO in
            1) add_user ;; 2) remove_user ;; 3) ls -1 "$DESTINO"; read -p "ENTER..." d ;;
            4) listar_online ;; 5) teste_velocidade ;; 6) trafego_acumulado ;;
            7) chamar_seguranca ;; 8) exit 0 ;;
        esac
    done
}

menu_ovp
