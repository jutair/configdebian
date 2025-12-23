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

# Instala dependências
if ! command -v speedtest-cli &> /dev/null || ! command -v vnstat &> /dev/null; then
    echo -e "${AMARELO}Instalando ferramentas de monitoramento...${SEM_COR}"
    apt update && apt install speedtest-cli vnstat bc -y
fi

# Cria a pasta de clientes se não existir
mkdir -p "$DESTINO"
chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO"

# --- FUNÇÕES ---

organizar_arquivos() {
    echo -e "${AMARELO}Sincronizando arquivos .ovpn para $DESTINO...${SEM_COR}"
    # Busca arquivos .ovpn criados nos últimos 10 minutos em /root ou na home do usuário
    find /root /home/$USER_ATUAL -maxdepth 1 -name "*.ovpn" -mmin -10 -exec mv {} "$DESTINO/" \; 2>/dev/null
    sudo chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO"
    sudo chmod -R 644 "$DESTINO"/*.ovpn 2>/dev/null
}

gerenciar_usuarios() {
    # Chama o script SEM o 'interactive' para você ter o controle total
    sudo bash "$INSTALLER_PATH"
    
    # Após sair do script do Angristan, organiza os novos arquivos
    organizar_arquivos
    echo -e "${VERDE}Feito! Retornando ao menu principal...${SEM_COR}"
    sleep 2
}

listar_arquivos_ovpn() {
    clear
    echo "======================================"
    echo "      ARQUIVOS .OVPN DISPONÍVEIS      "
    echo "======================================"
    ls -1 "$DESTINO"
    echo "--------------------------------------"
    read -p "Pressione ENTER para voltar..." dummy
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
    fi
    read -p "Pressione ENTER para voltar..." dummy
}

trafego_acumulado() {
    while true; do
        clear
        echo "======================================"
        echo "    RELATÓRIO DE TRÁFEGO (VNSTAT)     "
        echo "======================================"
        echo " [1] Relatório Diário"
        echo " [2] Relatório Mensal"
        echo " [3] Relatório Anual"
        echo " [4] Voltar"
        echo "--------------------------------------"
        read -p "Escolha: " PERIODO
        IFACE="eth0"; ip link show tun0 > /dev/null 2>&1 && IFACE="tun0"
        case $PERIODO in
            1) clear; vnstat -i "$IFACE" -d; read -p "ENTER..." d ;;
            2) clear; vnstat -i "$IFACE" -m; read -p "ENTER..." d ;;
            3) clear; vnstat -i "$IFACE" -y; read -p "ENTER..." d ;;
            4) return ;;
        esac
    done
}

chamar_seguranca() {
    if [ -f "$SCRIPT_REDE" ]; then
        bash "$SCRIPT_REDE"
    else
        echo -e "${VERMELHO}Script gerencia_rede.sh não encontrado!${SEM_COR}"
        sleep 2
    fi
}

menu_ovp() {
    while true; do
        clear
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e "                GERENCIADOR OPENVPN - DIGITALOCE                 "
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e " [1] Gerenciar Usuários (Add/Remover/Certificados)"
        echo -e " [2] Listar Arquivos .ovpn Gerados"
        echo -e " [3] Ver Usuários Online & Consumo"
        echo -e " [4] Testar Velocidade da Internet"
        echo -e " [5] Ver Tráfego Acumulado (VnStat)"
        echo -e " [6] Gerenciamento de Rede & Segurança"
        echo -e " [7] Sair"
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        read -p "Escolha uma opção: " OPCAO
        case $OPCAO in
            1) gerenciar_usuarios ;;
            2) listar_arquivos_ovpn ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER..." d ;;
            5) trafego_acumulado ;;
            6) chamar_seguranca ;;
            7) exit 0 ;;
            *) echo -e "${VERMELHO}Opção inválida!${SEM_COR}"; sleep 1 ;;
        esac
    done
}

menu_ovp
