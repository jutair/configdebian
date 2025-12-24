#!/bin/bash
# ===============================================================
# open_vpn_conf.sh - Gerenciador OpenVPN
# Detecção correta do usuário humano (SUDO_USER fix)
# ===============================================================

set +e

DIR_SCRIPTS="/opt/configdebian"
INSTALLER_PATH="$DIR_SCRIPTS/openvpn-install.sh interactive"

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# ===============================================================
# 1. DETECÇÃO CORRETA DO USUÁRIO HUMANO
# ===============================================================

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    USER_ATUAL="$SUDO_USER"
else
    USER_ATUAL=$(logname 2>/dev/null)
fi

[ -z "$USER_ATUAL" ] && USER_ATUAL=$(whoami)

# ===============================================================
# 2. DEFINIÇÃO DA PASTA DE DESTINO DOS .ovpn
# ===============================================================

if [ "$USER_ATUAL" = "root" ]; then
    DESTINO_USUARIO="/root/clientes_ovp"
else
    DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
fi

mkdir -p "$DESTINO_USUARIO"

# ===============================================================
# 3. LOCALIZAÇÃO DO STATUS.LOG DO OPENVPN
# ===============================================================

STATUS_LOG=$(grep -r "status " /etc/openvpn/*.conf /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)

[ -z "$STATUS_LOG" ] && [ -f "/etc/openvpn/server/openvpn-status.log" ] && STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
[ -z "$STATUS_LOG" ] && [ -f "/etc/openvpn/openvpn-status.log" ] && STATUS_LOG="/etc/openvpn/openvpn-status.log"

# ===============================================================
# 4. BLOQUEIO CTRL+C (MENU CONTROLADO)
# ===============================================================

trap '' SIGINT

# ===============================================================
# 5. FUNÇÕES
# ===============================================================

organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"

    find /root /home -maxdepth 2 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null

    if [ "$USER_ATUAL" != "root" ]; then
        chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO"
        chmod -R 700 "$DESTINO_USUARIO"
    fi
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "              ${VERDE}👥 UTILIZADORES VPN ONLINE${NC}"
    echo -e "${AZUL}==========================================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${AMARELO}Nenhum usuário VPN conectado.${NC}"
        read -p "Pressione ENTER para voltar..." d
        return
    fi

    printf "${AZUL}%-18s %-15s %-12s %-12s %-20s${NC}\n" \
        "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
    echo "----------------------------------------------------------------------------"

    grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r _ USER IP _ RX TX _ CONECTADO _; do
        RX_MB=$(awk -v v="${RX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        TX_MB=$(awk -v v="${TX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        printf "👤 %-18s %-15s %-12s %-12s %-20s\n" \
            "$USER" "${IP%%:*}" "${RX_MB}MB" "${TX_MB}MB" "$CONECTADO"
    done

    echo "----------------------------------------------------------------------------"
    read -p "Pressione ENTER para voltar..." d
}

# ===============================================================
# 6. MENU OPENVPN
# ===============================================================

menu_ovp() {
    while true; do
        VPN_ONLINE=0
        [ -f "$STATUS_LOG" ] && VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG")

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "        ${VERDE}GERENCIADOR OPENVPN — Usuário: $USER_ATUAL${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  ${AZUL}%-22s :${NC} ${VERDE}%s cliente(s) online${NC}\n" "STATUS VPN" "$VPN_ONLINE"
        printf "  ${AZUL}%-22s :${NC} ${AMARELO}%s${NC}\n" "PASTA .ovpn" "$DESTINO_USUARIO"
        echo -e "${AZUL}===============================================================${NC}"

        echo -e "  [1] 👤 Criar / Remover Clientes VPN"
        echo -e "  [2] 📂 Meus Arquivos .ovpn"
        echo -e "  [3] 👥 Ver Usuários VPN Online"
        echo -e "  [4] 📈 Consumo de Banda (vnStat)"
        echo -e "  [5] ⬅️  Voltar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"

        read -n 1 -p "Digite a opção: " OPCAO
        echo ""

        case $OPCAO in
            1)
                bash "$INSTALLER_PATH"
                organizar_arquivos
                ;;
            2)
                clear
                ls -lh "$DESTINO_USUARIO"/*.ovpn 2>/dev/null || echo "Nenhum arquivo."
                read -p "Pressione ENTER para voltar..." d
                ;;
            3)
                listar_online
                ;;
            4)
                clear
                vnstat
                read -p "Pressione ENTER para voltar..." d
                ;;
            5)
                trap - SIGINT
                return
                ;;
            *)
                echo -e "${VERMELHO}Opção inválida!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ===============================================================
# 7. INICIALIZA
# ===============================================================

menu_ovp
