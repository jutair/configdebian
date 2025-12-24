#!/bin/bash
# open_vpn_conf.sh - Gerenciador OpenVPN Profissional 24-12-2025-v4

set -e

# Identifica o usuário real (quem logou via SSH)
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})

# --- CORES ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- CAMINHOS ---
DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
DIR_SCRIPTS="/opt/configdebian"

INSTALLER_PATH="$DIR_SCRIPTS/openvpn-install.sh"
SCRIPT_REDE="$DIR_SCRIPTS/gerencia_rede.sh"

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C para manter a integridade do menu
trap '' SIGINT

# --- FUNÇÕES ---
organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"
    find /root /home/$USER_ATUAL -maxdepth 1 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO"
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "                ${VERDE}DETALHAMENTO DE USUÁRIOS VPN ONLINE${NC}"
    echo -e "${AZUL}==========================================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Erro: Log da VPN não encontrado.${NC}"
    else
        printf "${AZUL}%-15s %-15s %-12s %-12s %-15s${NC}\n" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD" "CONECTADO EM"
        echo "--------------------------------------------------------------------------"
        grep "^CLIENT_LIST" "$STATUS_LOG" | while read -r line; do
            SEP=$( [[ "$line" == *","* ]] && echo "," || echo $'\t' )
            USER=$(echo "$line" | cut -d"$SEP" -f2)
            IP=$(echo "$line" | cut -d"$SEP" -f3 | cut -d':' -f1)
            RECV=$(echo "$line" | cut -d"$SEP" -f5)
            SENT=$(echo "$line" | cut -d"$SEP" -f6)
            DATA=$(echo "$line" | cut -d"$SEP" -f8)

            RECV_MB=$(echo "scale=2; $_
