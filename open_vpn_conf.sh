#!/bin/bash
# open_vpn_conf.sh - Gestão OpenVPN Blindada (Versão 26/12/2025)

# --- CONFIGURAÇÕES DE IDENTIDADE ---
DIR_PROT="/etc/vps_protecao"
DIR_SCRIPTS="/opt/configdebian"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- 1. VERIFICAÇÃO DE ROOT AMIGÁVEL AO SUDO ---
if [[ $EUID -ne 0 ]]; then
    echo -e "${VERMELHO}❌ Erro: Este script exige privilégios administrativos.${NC}"
    echo -e "${AMARELO}O menu deve chamá-lo com 'sudo -E'.${NC}"
    sleep 2
    exit 1
fi

# 2. Carrega Administrador Oficial
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

# 3. Detecção AUID
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_ATUAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_ATUAL=$(whoami)
fi

# Define destinos
if [ "$USER_ATUAL" == "root" ]; then
    DESTINO_USUARIO="/root/clientes_ovp"
else
    DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
fi

# --- 🛡️ SEGURANÇA MÁXIMA ---
fechar_sessao_vpn() {
    if [[ "$USER_ATUAL" != "$ADM_USER" && "$USER_ATUAL" != "root" ]]; then
        echo -e "\n${VERMELHO}⚠️ SAÍDA BLOQUEADA! Encerrando conexão...${NC}"
        pkill -u "$USER_ATUAL" -9
        exit 1
    fi
}
trap fechar_sessao_vpn SIGINT SIGTSTP SIGQUIT

# --- FUNÇÕES ---

organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"
    find /root /home -maxdepth 2 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null
    if [ "$USER_ATUAL" != "root" ]; then
        chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO"
        chmod -R 755 "$DESTINO_USUARIO"
    fi
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "                ${VERDE}👥 USUÁRIOS VPN ONLINE${NC}"
    echo "----------------------------------------------------------------------------"
    STATUS_LOG=$(grep -r "status " /etc/openvpn/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    [ -z "$STATUS_LOG" ] && STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}❌ Log de status não encontrado.${NC}"; read -p "ENTER..." d; return
    fi

    printf "${AZUL}%-18s %-15s %-12s %-12s${NC}\n" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD"
    grep "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null | while IFS=',' read -r _ USER IP _ RX TX rest; do
        RX_MB=$(awk -v v="${RX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        TX_MB=$(awk -v v="${TX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        printf "👤 %-18s %-15s %-12s %-12s\n" "$USER" "${IP%%:*}" "${RX_MB}MB" "${TX_MB}MB"
    done
    echo -e "${AZUL}----------------------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para voltar..." d
}

listar_arquivos_ovpn() {
    clear
    organizar_arquivos
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}📂 DOWNLOAD DE ARQUIVOS .OVPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    IP_SERVIDOR=$(curl -s --max-time 2 ifconfig.me)
    if [ ! -d "$DESTINO_USUARIO" ] || [ -z "$(ls -A "$DESTINO_USUARIO"/*.ovpn 2>/dev/null)" ]; then
        echo -e "${VERMELHO}Nenhum arquivo encontrado em: $DESTINO_USUARIO${NC}"
        read -p "ENTER..." d; return
    fi
    echo -e "${AMARELO}Arquivos disponíveis para download:${NC}"
    ls "$DESTINO_USUARIO"/*.ovpn | xargs -n 1 basename | sed 's/^/  - /'
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Digite o nome do arquivo para obter o comando: " BUSCA
    [ -z "$BUSCA" ] && return
    ARQ_FINAL=$(ls "$DESTINO_USUARIO"/*"$BUSCA"*.ovpn 2>/dev/null | head -n1)
    if [ -n "$ARQ_FINAL" ]; then
        echo -e "\n${VERDE}Comando para download:${NC}"
        echo -e "${AMARELO}scp $USER_ATUAL@$IP_SERVIDOR:$ARQ_FINAL ./ ${NC}\n"
    else
        echo -e "${VERMELHO}Arquivo não encontrado.${NC}"
    fi
    read -p "Pressione ENTER..." d
}

# --- MENU PRINCIPAL ---

while true; do
    # Contador de usuários conectados
    STATUS_LOG_OVP="/etc/openvpn/server/openvpn-status.log"
    VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG_OVP" 2>/dev/null || echo "0")
    
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIADOR OPENVPN - $USER_ATUAL${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  ${AZUL}STATUS ONLINE :${NC} ${VERDE}$VPN_ONLINE Clientes${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 👤 Criar / Remover Usuários"
    echo -e "  [2] 📂 Baixar arquivo .ovpn (Comando SCP)"
    echo -e "  [3] 📊 Ver Detalhes dos Online"
    echo -e "  [4] ⚡ Testar Velocidade"
    echo -e "  [5] 📉 Consumo de Banda (VnStat)"
    echo -e "  [6] 🛡️  Definir Auto-Kill por Tráfego"
    echo -e "  [7] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    read -n 1 -p " Escolha: " OP; echo ""
    case $OP in
        1) 
            if [ -f "$DIR_SCRIPTS/openvpn-install.sh" ]; then
                bash "$DIR_SCRIPTS/openvpn-install.sh"
                organizar_arquivos
            else
                echo -e "${VERMELHO}Erro: openvpn-install.sh não encontrado.${NC}"
                sleep 2
            fi 
            ;;
        2) 
            listar_arquivos_ovpn 
            ;;
        3) 
            listar_online 
            ;;
        4) 
            clear; speedtest-cli --simple; read -p "ENTER..." d 
            ;;
        5) 
            clear; vnstat -d; read -p "ENTER..." d 
            ;;
        6) 
            if [[ "$USER_ATUAL" == "$ADM_USER" || "$USER_ATUAL" == "root" ]]; then
                read -p "Limite Mensal em GB: " LIM
                if [[ $LIM =~ ^[0-9]+$ ]]; then
                    # Criando o arquivo linha por linha para evitar erro de Heredoc no editor
                    echo '#!/bin/bash' > /opt/configdebian/auto_limite.sh
                    echo "CONSUMO=\$(vnstat --oneline | cut -d';' -f11 | sed 's/ GB//' | cut -d'.' -f1)" >> /opt/configdebian/auto_limite.sh
                    echo "if [ \"\$CONSUMO\" -ge \"$LIM\" ]; then" >> /opt/configdebian/auto_limite.sh
                    echo "    systemctl stop openvpn-server@server" >> /opt/configdebian/auto_limite.sh
                    echo "    ufw deny 1194/udp" >> /opt/configdebian/auto_limite.sh
                    echo "fi" >> /opt/configdebian/auto_limite.sh
                    chmod +x /opt/configdebian/auto_limite.sh
                    echo -e "${VERDE}Limite de $LIM GB configurado!${NC}"
                fi
            else
                echo -e "${VERMELHO}Ação permitida apenas para o Administrador.${NC}"
            fi
            sleep 2 
            ;;
        7) 
            exit 0 
            ;;
        *) 
            sleep 1 
            ;;
    esac
done
