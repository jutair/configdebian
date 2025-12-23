#!/bin/bash

# --- CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- VARIÁVEIS GLOBAIS ---
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)
SSH_CONF="/etc/ssh/sshd_config"

# --- 1. FUNÇÕES DE REDE ---

testa_velocidade() {
    clear
    echo "======================================"
    echo "        Velocidade da rede:           "
    echo "======================================"
    echo "Aguarde, testando a conexão da VPS..."
    RESULTADO=$(speedtest-cli --simple)
    PING=$(echo "$RESULTADO" | grep "Ping" | cut -d' ' -f2)
    DOWNLOAD=$(echo "$RESULTADO" | grep "Download" | cut -d' ' -f2)
    UPLOAD=$(echo "$RESULTADO" | grep "Upload" | cut -d' ' -f2)
    clear
    echo "Download: $DOWNLOAD Mbps | Upload: $UPLOAD Mbps | Ping: $PING ms"
    read -p "Pressione ENTER para voltar..." dummy
}

monitora_placa() {
    clear
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    echo "Monitorando interface: $INTERFACE (CTRL+C para parar)"
    vnstat -l -i "$INTERFACE"
    read -p "Pressione ENTER para voltar..." dummy
}

relatorio_consumo() {
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    while true; do
        clear
        echo "=== Relatório de Consumo ($INTERFACE) ==="
        echo "[1] Anual  [2] Mensal  [3] Diário  [4] Sair"
        read -n 1 -p "Opção: " OP; echo ""
        case $OP in
            1) vnstat -y -i "$INTERFACE"; read -p "ENTER..." d ;;
            2) vnstat -m -i "$INTERFACE"; read -p "ENTER..." d ;;
            3) vnstat -d -i "$INTERFACE"; read -p "ENTER..." d ;;
            4) break ;;
        esac
    done
}

# --- 2. FUNÇÕES DE SEGURANÇA (FIREWALL & FAIL2BAN) ---

monitora_banidos() {
    clear
    echo "=== RELATÓRIO DE BANIMENTOS (Fail2Ban) ==="
    JAILS=$(fail2ban-client status | grep "Jail list" | sed 's/.*list://' | tr -d ',')
    for jail in $JAILS; do
        TOTAL=$(fail2ban-client status "$jail" | grep "Total banned" | awk '{print $4}')
        IPS=$(fail2ban-client status "$jail" | grep "Banned IP list" | sed 's/.*list://')
        echo -e "\n[\033[1;33m$jail\033[0m] Total: $TOTAL"
        echo -e "Banidos agora: \033[31m${IPS:-Nenhum}\033[0m"
    done
    echo "------------------------------------------"
    echo "Últimos ataques (Failed Passwords):"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5
    read -p "Pressione ENTER..." dummy
}

gerenciar_fail2ban() {
    clear
    echo "=== GERENCIAR FAIL2BAN ==="
    echo "[1] Listar IPs Banidos  [2] Desbanir IP  [3] Logs Real  [4] Voltar"
    read -n 1 -p "Opção: " FOP; echo ""
    case $FOP in
        1) sudo fail2ban-client status sshd; read -p "ENTER..." d ;;
        2) read -p "IP para desbanir: " IP; sudo fail2ban-client set sshd unbanip "$IP" ;;
        3) sudo tail -f /var/log/auth.log | grep "Failed password" ;;
        *) return ;;
    esac
}

fire_config() {
    while true; do
        clear
        echo "=== CONFIGURAÇÃO DO FIREWALL (UFW) ==="
        echo "[1] Status [2] Abrir Porta [3] Bloquear IP [4] Fail2Ban [5] Reset [6] Sair"
        read -n 1 -p "Opção: " OP; echo ""
        case $OP in
            1) sudo ufw status numbered; read -p "ENTER..." d ;;
            2) read -p "Porta: " P; sudo ufw allow "$P" ;;
            3) read -p "IP: " I; sudo ufw deny from "$I" ;;
            4) gerenciar_fail2ban ;;
            5) sudo ufw --force reset; sudo ufw allow 22/tcp; sudo ufw allow 1194/udp; sudo ufw --force enable ;;
            6) break ;;
        esac
    done
}

# --- 3. FUNÇÕES DE SSH ---

ssh_config() {
    while true; do
        clear
        echo "=== CONFIGURAR SSH ==="
        echo "[1] Status/Porta [2] Mudar Porta [3] Root Login [4] Password Login [5] Derrubar User [6] Sair"
        read -n 1 -p "Opção: " OP; echo ""
        case $OP in
            1) clear; systemctl status ssh --no-pager; grep "^Port" $SSH_CONF; who; read -p "ENTER..." d ;;
            2) read -p "Nova Porta: " NP; sudo ufw allow "$NP"/tcp; sudo sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" | sudo tee -a $SSH_CONF; systemctl restart ssh ;;
            3) echo "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sudo sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" | sudo tee -a $SSH_CONF; systemctl restart ssh ;;
            4) echo "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sudo sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" | sudo tee -a $SSH_CONF; systemctl restart ssh ;;
            5) clear; who; read -p "Usuário para expulsar: " U; sudo usermod -L "$U"; sudo pkill -u "$U" -9; echo "Expulso!"; sleep 2 ;;
            6) break ;;
        esac
    done
}

# --- 4. MENUS DE NAVEGAÇÃO ---

menu_segrede() {
    while true; do
        clear
        echo "=== Painel de Segurança da Rede ==="
        echo "[1] Firewall  [2] SSH  [3] Relatório Banidos  [4] Voltar Menu Principal"
        read -n 1 -p "Opção: " OP; echo ""
        case $OP in
            1) fire_config ;;
            2) ssh_config ;;
            3) monitora_banidos ;;
            4) exec sudo -E bash "$HOME_HUMANA/configdebian-main/menu.sh" ;;
            *) return ;;
        esac
    done
}

# --- LOOP PRINCIPAL (ENTRADA DO SCRIPT) ---
while true; do
    IP_EXTERNO=$(curl -4 -s ifconfig.me || echo "Erro IP")
    clear
    echo "======================================"
    echo "          GERENCIAR REDE              "
    echo "IP Externo: $IP_EXTERNO"
    echo "======================================"
    echo "[1] Testar Velocidade"
    echo "[2] Monitorar Placa"
    echo "[3] Consumo Geral"
    echo "[4] Segurança (FW/SSH)"
    echo "[5] Sair"
    echo "======================================"
    read -n 1 -p "Opção: " OP; echo ""
    case $OP in
        1) testa_velocidade ;;
        2) monitora_placa ;;
        3) relatorio_consumo ;;
        4) menu_segrede ;;
        5) exec sudo -E bash "$HOME_HUMANA/configdebian-main/menu.sh" ;;
        *) echo "Inválido"; sleep 1 ;;
    esac
done
