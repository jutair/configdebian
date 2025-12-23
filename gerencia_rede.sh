#!/bin/bash
# gerencia_rede.sh - Gerenciador de Segurança e Rede Profissional

# --- VARIÁVEIS E CORES ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)
SSH_CONF="/etc/ssh/sshd_config"

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

# --- FUNÇÕES DE REDE ---

testa_velocidade() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "${AMARELO}Aguarde, testando a conexão da VPS...${NC}"
    RESULTADO=$(speedtest-cli --simple)
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    echo "$RESULTADO"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

monitora_placa() {
    clear
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    echo -e "${AMARELO}Monitorando interface: $INTERFACE (CTRL+C para parar)${NC}"
    vnstat -l -i "$INTERFACE"
}

# --- FUNÇÕES DE SEGURANÇA ---

monitora_banidos() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERMELHO}RELATÓRIO DE ATAQUES E BANIMENTOS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    JAILS=$(fail2ban-client status | grep "Jail list" | sed 's/.*list://' | tr -d ',')
    for jail in $JAILS; do
        TOTAL=$(fail2ban-client status "$jail" | grep "Total banned" | awk '{print $4}')
        IPS=$(fail2ban-client status "$jail" | grep "Banned IP list" | sed 's/.*list://')
        echo -e "${AMARELO}[$jail]${NC} Total histórico: ${VERMELHO}$TOTAL${NC}"
        echo -e "Banidos agora: ${VERMELHO}${IPS:-Nenhum}${NC}\n"
    done
    echo -e "${AZUL}Últimos ataques (Failed Passwords):${NC}"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p " Pressione ENTER para retornar..." dummy
}

ssh_config() {
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH"
        echo -e "  [2] 👤 Permitir/Bloquear Login Root"
        echo -e "  [3] 🔑 Permitir/Bloquear Senhas (Password Auth)"
        echo -e "  [4] 👢 Desconectar Usuário Ativo"
        echo -e "  [5] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Digite a opção: " OP; echo ""
        case $OP in
            1) read -p " Nova Porta: " NP; ufw allow "$NP"/tcp; sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" >> $SSH_CONF; systemctl restart ssh ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            3) echo -e "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            4) clear; who; read -p " Usuário para expulsar: " U; pkill -u "$U" -9; echo "Expulso!"; sleep 2 ;;
            5) break ;;
        esac
    done
}

# --- MENU PRINCIPAL DO MÓDULO ---

while true; do
    # Dados para o Dashboard de Rede
    IP_EXTERNO=$(curl -s --max-time 2 ifconfig.me || echo "Desconectado")
    PORTA_SSH=$(grep "^Port" $SSH_CONF | awk '{print $2}')
    [ -z "$PORTA_SSH" ] && PORTA_SSH="22"
    IFACE_PRINCIPAL=$(ip route | grep default | awk '{print $5}')
    TOTAL_BAN=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
    [ -z "$TOTAL_BAN" ] && TOTAL_BAN="0"

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "            ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "IP SERVIDOR" "$IP_EXTERNO"
    printf "  ${AZUL}%-15s :${NC} ${AMARELO}%-20s${NC}\n" "PORTA SSH" "$PORTA_SSH"
    printf "  ${AZUL}%-15s :${NC} ${VERDE}%-20s${NC}\n" "INTERFACE" "$IFACE_PRINCIPAL"
    printf "  ${AZUL}%-15s :${NC} ${VERMELHO}%-20s${NC}\n" "IPs BANIDOS" "$TOTAL_BAN (Fail2Ban)"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] ⚡ Testar Velocidade"
    echo -e "  [2] 📊 Monitorar Tráfego Real (Live)"
    echo -e "  [3] 📉 Relatórios de Consumo (VnStat)"
    echo -e "  [4] 🛡️  Firewall e Fail2Ban (Banimentos)"
    echo -e "  [5] 🔑 Configurações do SSH"
    echo -e "  [6] ⬅️  Retornar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) testa_velocidade ;;
        2) monitora_placa ;;
        3) 
            while true; do
                clear
                echo "=== Relatórios VnStat ($IFACE_PRINCIPAL) ==="
                echo "[1] Diário  [2] Mensal  [3] Voltar"
                read -n 1 -p "Opção: " VO; echo ""
                case $VO in
                    1) vnstat -d; read -p "ENTER..." d ;;
                    2) vnstat -m; read -p "ENTER..." d ;;
                    3) break ;;
                esac
            done ;;
        4) 
            while true; do
                clear
                echo "=== Segurança e Firewall ==="
                echo "[1] Ver Regras UFW  [2] IPs Banidos  [3] Abrir Porta  [4] Voltar"
                read -n 1 -p "Opção: " FO; echo ""
                case $FO in
                    1) ufw status numbered; read -p "ENTER..." d ;;
                    2) monitora_banidos ;;
                    3) read -p "Porta: " P; ufw allow "$P"; echo "Porta $P aberta!"; sleep 2 ;;
                    4) break ;;
                esac
            done ;;
        5) ssh_config ;;
        6) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
