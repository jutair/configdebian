#!/bin/bash
# open_vpn_conf.sh - Gerenciador OpenVPN (Versão Fix Usuários - 24-12-2025)
#Corrigindo a autorização de usuários
# Removido set -e para evitar fechamento inesperado
DIR_SCRIPTS="/opt/configdebian"

# Lógica de detecção de usuário aprimorada (Não trava se falhar)
if [ -n "$SUDO_USER" ]; then
    USER_ATUAL="$SUDO_USER"
elif command -v logname >/dev/null 2>&1; then
    USER_ATUAL=$(logname 2>/dev/null || whoami)
else
    USER_ATUAL=$(whoami)
fi

DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
INSTALLER_PATH="$DIR_SCRIPTS/openvpn-install.sh"
SCRIPT_REDE="$DIR_SCRIPTS/gerencia_rede.sh"

AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Bloqueia CTRL+C para não quebrar o menu
trap '' SIGINT

# --- FUNÇÕES ---

organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"
    # Tenta mover arquivos .ovpn recém criados
    find /root /home -maxdepth 2 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null || true
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO" 2>/dev/null || true
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "              ${VERDE}👥 USUÁRIOS VPN ONLINE (TEMPO REAL)${NC}"
    echo -e "${AZUL}==========================================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}❌ Log da VPN não encontrado em:${NC} $STATUS_LOG"
        read -p "Pressione ENTER para voltar..." dummy
        return
    fi

    printf "${AZUL}%-3s %-18s %-15s %-12s %-12s %-20s${NC}\n" \
        " " "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
    echo "----------------------------------------------------------------------------"

    # Uso de grep direto (sem sudo interno para não pedir senha de novo)
    grep "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null | \
    while IFS=',' read -r _ USER IP _ RX TX _ CONECTADO _; do
        RX_MB=$(awk -v v="${RX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        TX_MB=$(awk -v v="${TX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        ICON="👤"
        [[ "$USER" == *"celular"* ]] && ICON="📱"
        [[ "$USER" == *"notebook"* || "$USER" == *"pc"* ]] && ICON="💻"

        printf "%-3s %-18s %-15s %-12s %-12s %-20s\n" \
            "$ICON" "$USER" "${IP%%:*}" "${RX_MB}MB" "${TX_MB}MB" "$CONECTADO"
    done

    echo "----------------------------------------------------------------------------"
    read -p "Pressione ENTER para retornar..." dummy
}

menu_ovp() {
    while true; do
        # Captura estatísticas básicas
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "            ${VERDE}GERENCIADOR OPENVPN - CONECTADO COMO: $USER_ATUAL${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "USUÁRIOS VPN" "$VPN_ONLINE Online"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 👤 Criar / Remover Usuários"
        echo -e "  [2] 📂 Meus Arquivos .ovpn"
        echo -e "  [3] 📊 Ver Detalhes dos Online"
        echo -e "  [4] ⚡ Testar Velocidade"
        echo -e "  [5] 📈 Consumo de Banda (VnStat)"
        echo -e "  [6] ⬅️  Retornar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        
        read -n 1 -p "Digite a opção: " OPCAO; echo ""

        case $OPCAO in
            1) if [ -f "$INSTALLER_PATH" ]; then 
                   bash "$INSTALLER_PATH"
                   organizar_arquivos
               else
                   echo -e "${VERMELHO}Instalador não encontrado!${NC}"; sleep 2
               fi ;;
            2) clear; echo -e "${VERDE}Configurações em $DESTINO_USUARIO:${NC}"; ls "$DESTINO_USUARIO"/*.ovpn 2>/dev/null || echo "Vazio."; read -p "ENTER..." d ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER..." d ;;
            5) clear; vnstat -d; read -p "ENTER..." d ;;
            6) return 0 ;; 
            *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
        esac
    done
}

# Inicia o Menu
menu_ovp
