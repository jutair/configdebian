#!/bin/bash
# open_vpn_conf.sh - Gerenciador OpenVPN Profissional (Atualizado 24-12-2025)

set -e

USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
DIR_SCRIPTS="/opt/configdebian"
DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/var/log/openvpn/status.log"
INSTALLER_PATH="$DIR_SCRIPTS/openvpn-install.sh"
SCRIPT_REDE="$DIR_SCRIPTS/gerencia_rede.sh"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C
trap '' SIGINT

organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"
    find /root /home/$USER_ATUAL -maxdepth 1 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO"
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "                ${VERDE}👥 USUÁRIOS VPN ONLINE${NC}"
    echo -e "${AZUL}==========================================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Erro: Log da VPN não encontrado (${STATUS_LOG}).${NC}"
        read -p " Pressione ENTER para retornar..." dummy
        return
    fi

    printf "${AZUL}%-3s %-18s %-15s %-12s %-12s %-19s${NC}\n" \
        "" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
    echo "--------------------------------------------------------------------------------"

    grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ USER IP _ BYTES_IN BYTES_OUT _ CONN_DATE _; do

        # Segurança contra valores vazios
        BYTES_IN=${BYTES_IN:-0}
        BYTES_OUT=${BYTES_OUT:-0}

        # Conversão segura para MB
        RX_MB=$(awk "BEGIN { printf \"%.2f\", $BYTES_IN/1048576 }")
        TX_MB=$(awk "BEGIN { printf \"%.2f\", $BYTES_OUT/1048576 }")

        # Ícone por tipo de dispositivo (heurística simples)
        ICON="👤"
        [[ "$USER" == *"celular"* || "$USER" == *"mobile"* ]] && ICON="📱"
        [[ "$USER" == *"note"* || "$USER" == *"laptop"* ]] && ICON="💻"
        [[ "$USER" == *"pc"* || "$USER" == *"desktop"* ]] && ICON="🖥️"

        printf "%-3s %-18s %-15s %-12s %-12s %-19s\n" \
            "$ICON" "$USER" "$IP" "${RX_MB}MB" "${TX_MB}MB" "$CONN_DATE"
    done

    echo -e "${AZUL}--------------------------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}


gerar_link_ovpn() {
    clear
    USUARIO_REAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$USER})
    CAMINHO_BUSCA="/home/$USUARIO_REAL/clientes_ovp"
    [ -z "$IP_EXT" ] && IP_EXT=$(curl -s --max-time 2 ifconfig.me)

    if [ ! -d "$CAMINHO_BUSCA" ]; then
        echo -e "${VERMELHO}Erro: Pasta não encontrada em $CAMINHO_BUSCA${NC}"
        read -p "ENTER para voltar..." dummy
        return
    fi

    FILES=$(ls "$CAMINHO_BUSCA"/*.ovpn 2>/dev/null)
    if [ -z "$FILES" ]; then
        echo -e "${AMARELO}Nenhum arquivo .ovpn encontrado.${NC}"
    else
        echo -e "${VERDE}Comandos SCP para baixar os arquivos:${NC}\n"
        for file in $FILES; do
            FILENAME=$(basename "$file")
            echo -e "${AMARELO}➜ $FILENAME${NC}"
            echo "scp ${USUARIO_REAL}@${IP_EXT}:~/clientes_ovp/${FILENAME} ./"
            echo ""
        done
    fi
    read -p "Pressione ENTER para retornar..." dummy
}

menu_ovp() {
    while true; do
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        CPU_USO=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
        MEM_USO=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
        
        # Detecta interface tun*
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep 'tun[0-9]+' | head -n1)
        IFACE=${IFACE:-"eth0"}
        BANDA_VPN=$(vnstat -i "$IFACE" --oneline 2>/dev/null | cut -d';' -f6)
        [[ -z "$BANDA_VPN" || "$BANDA_VPN" == *"No data"* ]] && BANDA_VPN="0.00 MB"

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "            ${VERDE}GERENCIADOR OPENVPN - DIGITALOCE${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "STATUS SERVIÇO" "Ativo ($IFACE)"
        printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "USUÁRIOS VPN" "$VPN_ONLINE Conectados"
        printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "TRÁFEGO VPN" "$BANDA_VPN (Hoje)"
        printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "CPU / RAM" "$CPU_USO / $MEM_USO"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 👤 Gerenciar Usuários (Criar/Remover)"
        echo -e "  [2] 📂 Baixar aquivo cliente ovpn"
        echo -e "  [3] 📊 Ver Detalhes dos Online & Consumo"
        echo -e "  [4] ⚡ Testar Velocidade da Internet"
        echo -e "  [5] 📈 Relatórios VnStat (Dia/Mês)"
        echo -e "  [6] 🛡️ Segurança e Firewall"
        echo -e "  [7] ⬅️  Retornar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p "Digite a opção: " OPCAO
        echo ""

        case $OPCAO in
            1) sudo bash "$INSTALLER_PATH" interactive; organizar_arquivos ;;
            2) gerar_link_ovpn ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER para voltar..." dummy ;;
            5) clear; vnstat -i "$IFACE" -d; read -p "ENTER para voltar..." dummy ;;
            6) [ -f "$SCRIPT_REDE" ] && bash "$SCRIPT_REDE" || echo "Script não encontrado" ;;
            7) exit 0 ;;
            *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
        esac
    done
}

menu_ovp
