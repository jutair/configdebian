#!/bin/bash
# open_vpn_conf.sh - Gerenciador OpenVPN Profissional

# Identifica o usuário real para caminhos de arquivos
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})

# --- CORES ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
DESTINO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
SCRIPT_REDE="/home/$USER_ATUAL/configdebian-main/gerencia_rede.sh"

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  exit 1
fi

# Bloqueia CTRL+C para manter a integridade do menu
trap '' SIGINT

# --- FUNÇÕES DE APOIO ---

organizar_arquivos() {
    [ ! -d "$DESTINO" ] && mkdir -p "$DESTINO"
    find /root /home/$USER_ATUAL -maxdepth 1 -name "*.ovpn" -exec mv {} "$DESTINO/" \; 2>/dev/null
    chown -R "$USER_ATUAL:$USER_ATUAL" "$DESTINO"
}

# --- FUNÇÕES DO MENU ---

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
            # Detecta se o separador é vírgula ou tab
            SEP=$( [[ "$line" == *","* ]] && echo "," || echo $'\t' )
            USER=$(echo "$line" | cut -d"$SEP" -f2)
            IP=$(echo "$line" | cut -d"$SEP" -f3 | cut -d':' -f1)
            RECV=$(echo "$line" | cut -d"$SEP" -f5)
            SENT=$(echo "$line" | cut -d"$SEP" -f6)
            DATA=$(echo "$line" | cut -d"$SEP" -f8)
            
            # Conversão para MB
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
    # Detecta o usuário real da seção (ignora o sudo para pegar a home correta)
    USUARIO_DA_SESSAO=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
    CAMINHO_BUSCA="/home/$USUARIO_DA_SESSAO/clientes_ovp"
    
    # Garante o IP Externo
    [ -z "$IP_EXT" ] && IP_EXT=$(curl -s --max-time 2 ifconfig.me)

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "             ${VERDE}MEUS ARQUIVOS OVPN DISPONÍVEIS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e " Usuário: ${AMARELO}$USUARIO_DA_SESSAO${NC}"
    echo -e " Pasta:   ${AMARELO}$CAMINHO_BUSCA${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    # Verifica se a pasta existe
    if [ ! -d "$CAMINHO_BUSCA" ]; then
        echo -e "${VERMELHO}Erro: Sua pasta 'clientes_ovp' não foi encontrada.${NC}"
        echo -e "Certifique-se de que o diretório existe em sua HOME."
        read -p " ENTER para voltar..." d; return
    fi

    FILES=$(ls "$CAMINHO_BUSCA"/*.ovpn 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo -e "${AMARELO}Nenhum arquivo .ovpn encontrado na sua pasta.${NC}"
    else
        echo -e "${VERDE}Copie e cole no terminal do seu Computador Local:${NC}\n"
        
        for file in $FILES; do
            FILENAME=$(basename "$file")
            echo -e "${AMARELO}➜ $FILENAME${NC}"
            echo -e "scp root@$IP_EXT:$file ./"
            echo ""
        done
    fi
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}
menu_ovp() {
    while true; do
        # --- COLETA DE DADOS PARA O DASHBOARD ---
        # Conta usuários VPN ativos no log do servidor
        VPN_ONLINE=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || echo "0")
        
        # Uso de CPU e RAM
        CPU_USO=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
        MEM_USO=$(free -m | awk '/Mem:/ { printf("%d%%", $3/$2*100) }')
        
        # Tráfego do dia na interface tun0 (VPN)
        BANDA_VPN=$(vnstat -i tun0 --oneline 2>/dev/null | cut -d';' -f6)
        [ -z "$BANDA_VPN" ] || [[ "$BANDA_VPN" == *"No data"* ]] && BANDA_VPN="0.00 MB"

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
                sudo bash "$INSTALLER_PATH"
                organizar_arquivos
                ;;
            2) 
                clear
                gerar_link_ovpn   # <-- Chamada da nova função
                ;;
            3) listar_online ;;
            4) clear; speedtest-cli --share; read -p "ENTER para voltar..." d ;;
            5) 
                clear
                vnstat -i tun0 -d
                echo ""
                read -p "ENTER para voltar..." d 
                ;;
            6) [ -f "$SCRIPT_REDE" ] && bash "$SCRIPT_REDE" || echo "Script não encontrado";;
            7) 
                echo -e "${VERDE}Saindo do módulo VPN...${NC}"
                sleep 1
                exit 0
                ;;
            *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
        esac
    done
}

# Inicia o menu
menu_ovp
