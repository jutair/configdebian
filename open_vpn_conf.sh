#!/bin/bash
# ===============================================================
# open_vpn_conf.sh - Versão "AUID - Absolute User ID"
# ===============================================================

DIR_SCRIPTS="/opt/configdebian"

# --- 1. DETECÇÃO PELO UID DE LOGIN (A prova de falhas) ---
# O arquivo /proc/self/loginuid guarda o ID de quem iniciou a sessão.
# Se for 4294967295, significa que não houve login (sessão de sistema).
AUID=$(cat /proc/self/loginuid 2>/dev/null)

if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    # Converte o ID numérico no nome do usuário
    USER_ATUAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    # Se o ID for 0 ou inválido, tentamos o dono da sessão física
    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
fi

# Fallback final para root
[ -z "$USER_ATUAL" ] && USER_ATUAL="root"

# Define a pasta de destino
if [ "$USER_ATUAL" == "root" ]; then
    DESTINO_USUARIO="/root/clientes_ovp"
else
    DESTINO_USUARIO="/home/$USER_ATUAL/clientes_ovp"
fi

# --- 2. LOCALIZADOR DE LOG ---
STATUS_LOG=$(grep -r "status " /etc/openvpn/*.conf /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
[ -z "$STATUS_LOG" ] && STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

INSTALLER_PATH="$DIR_SCRIPTS/openvpn-install.sh"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

trap '' SIGINT

# --- 3. FUNÇÕES ---

organizar_arquivos() {
    mkdir -p "$DESTINO_USUARIO"
    find /root /home -maxdepth 2 -name "*.ovpn" -exec mv {} "$DESTINO_USUARIO/" \; 2>/dev/null || true
    if [ "$USER_ATUAL" != "root" ]; then
        chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO_USUARIO"
        chmod -R 755 "$DESTINO_USUARIO"
    fi
}

listar_online() {
    clear
    echo -e "${AZUL}==========================================================================${NC}"
    echo -e "              ${VERDE}👥 USUÁRIOS VPN ONLINE${NC}"
    echo "----------------------------------------------------------------------------"
    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}❌ Log não encontrado.${NC}"; read -p "ENTER..." d; return
    fi
    printf "${AZUL}%-18s %-15s %-12s %-12s${NC}\n" "USUÁRIO" "IP REAL" "DOWNLOAD" "UPLOAD"
    grep "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null | while IFS=',' read -r _ USER IP _ RX TX rest; do
        RX_MB=$(awk -v v="${RX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        TX_MB=$(awk -v v="${TX:-0}" 'BEGIN {printf "%.2f", v/1048576}')
        printf "👤 %-18s %-15s %-12s %-12s\n" "$USER" "${IP%%:*}" "${RX_MB}MB" "${TX_MB}MB"
    done
    read -p "ENTER..." d
}

# ... (início do seu script open_vpn_conf.sh com a detecção de AUID que já funciona)
listar_arquivos_ovpn() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "               ${VERDE}📂 MEUS ARQUIVOS .OVPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    # 1. Define a pasta de busca (Home do usuário real)
    HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)
    PASTA_BUSCA="$HOME_HUMANA/clientes_ovp"
    
    # 2. Obtém o IP público do servidor
    IP_SERVIDOR=$(curl -s https://api.ipify.org)

    echo -e "${AMARELO}Usuário detectado:${NC} $USER_REAL"
    echo -e "${AMARELO}Diretório:${NC} $PASTA_BUSCA"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    # 3. Lista os arquivos .ovpn
    mapfile -t ARQUIVOS < <(ls "$PASTA_BUSCA"/*.ovpn 2>/dev/null)

    if [ ${#ARQUIVOS[@]} -eq 0 ]; then
        echo -e "${VERMELHO}Nenhum arquivo .ovpn encontrado na sua pasta home.${NC}"
    else
        echo -e "${VERDE}Arquivos encontrados:${NC}"
        for arquivo in "${ARQUIVOS[@]}"; do
            NOME_ARQ=$(basename "$arquivo")
            echo -e "\n${AMARELO}📄 Arquivo:${NC} $NOME_ARQ"
            
            # Gera o comando SCP pronto para o usuário
            echo -e "${AZUL}Comando para baixar (execute no seu PC):${NC}"
            echo -e "\033[1;37mscp $USER_REAL@$IP_SERVIDOR:$arquivo ./\033[0m"
        done
    fi

    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p "Pressione ENTER para voltar..." dummy
}

menu_ovp() {
    while true; do
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        # Lê o limite atual do script de proteção para mostrar no menu
        LIMITE_ATUAL=$(grep "LIMITE_GB=" /opt/configdebian/auto_limite.sh | cut -d'=' -f2 || echo "Não definido")
        
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "            ${VERDE}GERENCIADOR OPENVPN - LOGADO: $USER_ATUAL${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        printf "  ${AZUL}%-15s :${NC} ${VERDE}%s Cliente(s) Online${NC}\n" "STATUS" "$VPN_ONLINE"
        printf "  ${AZUL}%-15s :${NC} ${VERMELHO}%s GB${NC}\n" "LIMITE ATUAL" "$LIMITE_ATUAL"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 👤 Criar / Remover Usuários"
        echo -e "  [2] 📂 Baixar arquivo do cliente .ovpn"
        echo -e "  [3] 📊 Ver Detalhes dos Online"
        echo -e "  [4] ⚡ Testar Velocidade"
        echo -e "  [5] 📈 Consumo de Banda"
        echo -e "  [6] 🛡️  Definir Limite de Tráfego (Auto-Kill)"
        echo -e "  [7] ⬅️  Retornar ao Menu Principal"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p "Opção: " OPCAO; echo ""
        
        case $OPCAO in
            1) if [ -f "$INSTALLER_PATH" ]; then bash "$INSTALLER_PATH" interactive; organizar_arquivos; else echo "Erro!"; sleep 2; fi ;;
            2) listar_arquivos_ovpn ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER..." d ;;
            5) clear; vnstat -d; read -p "ENTER..." d ;;
            6) 
                clear
                echo -e "${AMARELO}Configuração de Proteção de Tráfego${NC}"
                read -p "Digite o limite máximo mensal desejado (em GB): " NOVO_LIMITE
                # Verifica se é um número
                if [[ $NOVO_LIMITE =~ ^[0-9]+$ ]]; then
                    # Sobrescreve ou cria o script de monitoramento
                    cat <<EOF > /opt/configdebian/auto_limite.sh
#!/bin/bash
LIMITE_GB=$NOVO_LIMITE
IFACE_WEB=\$(ip route | grep default | awk '{print \$5}' | head -n1)
CONSUMO_ATUAL=\$(vnstat -i \$IFACE_WEB --oneline | cut -d';' -f11 | sed 's/ GB//' | cut -d'.' -f1)

if [ -n "\$CONSUMO_ATUAL" ] && [ "\$CONSUMO_ATUAL" -ge "\$LIMITE_GB" ]; then
    systemctl stop openvpn
    systemctl stop openvpn-server@server
    ufw deny 1194/udp
fi
EOF
                    chmod +x /opt/configdebian/auto_limite.sh
                    echo -e "${VERDE}Sucesso! Limite de $NOVO_LIMITE GB aplicado.${NC}"
                else
                    echo -e "${VERMELHO}Erro: Digite apenas números.${NC}"
                fi
                sleep 2
                ;;
            7) return 0 ;;
            *) echo -e "${VERMELHO}Inválido!${NC}"; sleep 1 ;;
        esac
    done
}

menu_ovp
