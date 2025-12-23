#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# --- CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- VERIFICAÇÃO ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
    exit 1
fi

# --- CONFIGURAÇÃO E DETECÇÃO DO INSTALADOR ---
# Procura o instalador em locais comuns para evitar o erro de "não localizado"
if [ -f "/home/$USER_ATUAL/configdebian-main/openvpn-install.sh" ]; then
    INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
elif [ -f "./openvpn-install.sh" ]; then
    INSTALLER_PATH="./openvpn-install.sh"
else
    INSTALLER_PATH="/home/$USER_ATUAL/openvpn-install.sh"
fi

# Se não existir em nenhum lugar, baixa o oficial
if [ ! -f "$INSTALLER_PATH" ]; then
    echo -e "${AMARELO}[!] Instalador Angristan não localizado. Baixando...${SEM_COR}"
    wget -O "$INSTALLER_PATH" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x "$INSTALLER_PATH"
fi

STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"
INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

# --- FUNÇÕES DE APOIO ---

sincronizar_ovpns() {
    DESTINO="/home/$USER_ATUAL/clientes_ovp"
    mkdir -p "$DESTINO"
    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)
    if [ -n "$ARQUIVOS" ]; then
        echo "$ARQUIVOS" | while read -r arq; do
            mv "$arq" "$DESTINO/"
            chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO/$(basename "$arq")"
            chmod 644 "$DESTINO/$(basename "$arq")"
        done
    fi
}

# --- FUNÇÕES DE CONSUMO E STATUS ---

user_consumo() {
    clear
    echo "==============================================================="
    echo "               CONSUMO DE DADOS (Sessão Atual)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${VERMELHO}Erro: Log de status não encontrado.${SEM_COR}"
    else
        grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
            USER=$(echo "$line" | cut -d',' -f2)
            RECV_B=$(echo "$line" | cut -d',' -f5)
            SENT_B=$(echo "$line" | cut -d',' -f6)

            RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc 2>/dev/null || echo "0.00")
            SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc 2>/dev/null || echo "0.00")
            TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc 2>/dev/null || echo "0.00")

            printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
        done
    fi
    echo "---------------------------------------------------------------"
    read -p "Pressione ENTER para voltar..." dummy
}

user_online() {
    clear
    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"
    if [ -f "$STATUS_FILE" ]; then
        grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
            USER=$(echo "$line" | cut -d',' -f2)
            IP_R=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
            IP_V=$(echo "$line" | cut -d',' -f4)
            DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')
            printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_R" "$IP_V" "$DESDE"
        done
    else
        echo "Arquivo de log não encontrado."
    fi
    read -p "Pressione ENTER..." d
}

listar_usuarios_pki() {
    clear
    echo "==============================================================="
    echo "              RELATÓRIO DE USUÁRIOS (PKI)"
    echo "==============================================================="
    if [ -f "$INDEX_FILE" ]; then
        echo -e "${VERDE}[ ATIVOS ]${SEM_COR}"
        grep "^V" "$INDEX_FILE" | while read -r line; do
            USER=$(echo "$line" | awk -F'=' '{print $2}')
            DATA_RAW=$(echo "$line" | awk '{print $2}')
            DATA_BR="20${DATA_RAW:0:2}-${DATA_RAW:2:2}-${DATA_RAW:4:2}"
            printf "%-20s %-25s\n" "$USER" "$DATA_BR"
        done
    else
        echo "Banco de dados PKI não localizado."
    fi
    read -p "ENTER para voltar..." d
}

# --- MENU PRINCIPAL VPN ---

menu_ovp() {
    IP_
