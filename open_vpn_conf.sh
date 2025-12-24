#!/bin/bash
# open_vpn_conf.sh - Gerenciador OpenVPN Profissional 24-12-2025-v5

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

            RECV_MB=$(echo "scale=2; $RECV/1048576" | bc)
            SENT_MB=$(echo "scale=2; $SENT/1048576" | bc)

            printf "%-15s %-15s %-12s %-12s %-15s\n" "$USER" "$IP" "${RECV_MB}MB" "${SENT_MB}MB" "$DATA"
        done
    fi
    echo -e "${AZUL}--------------------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

gerar_link_ovpn() {
    clear
    USUARIO_REAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$USER})
    CAMINHO_BUSCA="/home/$USUARIO_REAL/clientes_ovp"

    [ -z "$IP_EXT" ] && IP_EXT=$(curl -s --max-time 2 ifconfig.me)

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "             ${VERDE}MEUS ARQUIVOS OVPN DISPONÍVEIS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e " Usuário: ${AMARELO}$USUARIO_REAL${NC}"
    echo -e " Pasta:   ${AMARELO}$CAMINHO_BUSCA${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    if [ ! -d "$CAMINHO_BUSCA" ]; then
        echo -e "${VERMELHO}Erro: Pasta não encontrada em $CAMINHO_BUSCA${NC}"
        read -p " ENTER para voltar..." dummy
        return
    fi

    FILES=$(ls "$CAMINHO_BUSCA"/*.ovpn 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${AMARELO}Nenhum arquivo .ovpn encontrado.${NC}"
    else
        echo -e "${VERDE}Copie e cole no terminal do seu PC (Windows/Linux):${NC}\n"
        for file in $FILES; do
            FILENAME=$(basename "$file")
            echo -e "${AMARELO}➜ $FILENAME${NC}"
            echo -e "scp ${USUARIO_REAL}@${IP_EXT}:~/clientes_ovp/${FILENAME} ./"
            echo ""
        done
    fi

    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

menu_ovp() {
    while true; do
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        CPU_USO=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
        MEM_USO=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
        
        # --- DETECTA INTERFACE TUN0 ---
        BANDA_VPN="0.00 MB"
        if ip link show tun0 >/dev/null 2>&1; then
            TMP_BANDA=$(vnstat -i tun0 --oneline 2>/dev/null | cut -d';' -f6)
            if [ -n "$TMP_BANDA" ] && [[ "$TMP_BANDA" != *"No data"* ]]; then
                BANDA_VPN="$TMP_BANDA"
            fi
        fi

        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "            ${VERDE}GERENCIADOR OPENVPN - DIGITALOCE${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "STATUS SERVIÇO" "Ativo (tun0)"
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
        read -n 1 -p " Digite a opção: " OPCAO
        echo ""

        case $OPCAO in
            1)
                sudo bash "$INSTALLER_PATH" interactive
                organizar_arquivos
                ;;
            2) gerar_link_ovpn ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER para voltar..." dummy ;;
            5) clear; vnstat -i tun0 -d; echo ""; read -p "ENTER para voltar..." dummy ;;
            6) [ -f "$SCRIPT_REDE" ] && bash "$SCRIPT_REDE" || echo "Script não encontrado" ;;
            7) echo -e "${VERDE}Saindo do módulo VPN...${NC}"; sleep 1; exit 0 ;;
            *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
        esac
    done
}

# Inicia o menu
menu_ovp
