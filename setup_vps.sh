#!/bin/bash
# setup_vps.sh - Instalador de Segurança e Gestão VPS
# Atualizado: 27-12-2025

# --- CORES ---
VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; VERDE='\033[0;32m'; AZUL='\033[0;34m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este script precisa de privilégios de ROOT.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

set -e

# --- CONFIGURAÇÕES ---
DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "setup_vps.sh" "guardiao.sh" "login.sh" "client-disconnect.sh" "client-connect.sh")

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           ${VERDE}INSTALADOR DE SEGURANÇA E GESTÃO VPS${NC}"
echo -e "                SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# --- 1. COLETA DE DADOS ---
echo -e "${AMARELO}👤 Cadastro de Usuários do Sistema:${NC}"
read -p " Nome para o ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# --- 2. PERGUNTA DE CONFIGURAÇÃO IMEDIATA ---
echo -e "${AMARELO}📢 Configuração de Alertas Telegram:${NC}"
echo -e "Deseja configurar o Bot do Telegram agora?"
echo -e " [1] Sim, configurar agora"
echo -e " [2] Não, configurar depois (pelo Menu de Rede)"
read -n 1 -p " Escolha: " OP_TELE; echo ""

if [[ "$OP_TELE" == "1" ]]; then
    read -p " Token do Bot: " TOKEN
    read -p " ID do Chat: " ID_CHAT
else
    TOKEN="NAO_DEFINIDO"
    ID_CHAT="NAO_DEFINIDO"
fi
echo -e "${AZUL}---------------------------------------------------------------${NC}"

# --- 3. CRIAÇÃO DAS PASTAS E ARQUIVOS ---
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"

echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/admin.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/admin.conf"
echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"

chmod 700 "$DIR_PROT"
chmod 600 "$DIR_PROT/admin.conf"
chmod 600 "$DIR_PROT/telegram.conf"

# --- 4. INSTALAÇÃO DE PACOTES ---
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc jq unzip procps speedtest-cli dnsmasq

# Define o fuso horário para Manaus
timedatectl set-timezone America/Manaus
timedatectl set-ntp true

# Inicia o vnstat
systemctl enable vnstat
systemctl start vnstat

# --- 5. DOWNLOAD DOS SCRIPTS ---
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    URL_DOWNLOAD="$GITHUB_REPO/$SCRIPT"
    curl -fsSL "$URL_DOWNLOAD" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# --- 6. CRIAÇÃO DE USUÁRIOS NO LINUX ---
echo -e "${AMARELO}👤 Configurando contas de acesso...${NC}"
for USUARIO in "$ADM_USER" "$OPE_USER"; do
    if ! id "$USUARIO" &>/dev/null; then
        useradd -m -s /bin/bash "$USUARIO"
        [ "$USUARIO" == "$ADM_USER" ] && SENHA="$ADM_PASS" || SENHA="$OPE_PASS"
        echo "$USUARIO:$SENHA" | chpasswd
    fi
done
usermod -aG sudo "$ADM_USER"
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# --- 7. BLINDAGEM E LIBERAÇÃO DE ACESSO ---
echo -e "${AMARELO}🛡️ Aplicando travas e liberando SSH por senha...${NC}"
SSH_CONF="/etc/ssh/sshd_config"
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONF
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONF
sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' $SSH_CONF
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONF

# Configura execução do login.sh no SSH
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so $DIR_CONFIG/login.sh" >> /etc/pam.d/sshd

# Configura o menu automático
sed -i '/menu.sh/d' /etc/profile
echo "[ -f $DIR_CONFIG/menu.sh ] && exec bash $DIR_CONFIG/menu.sh" >> /etc/profile

systemctl restart ssh

# --- 8. Proteção contra Fork Bomb e Limite de Processos ---
echo -e "${AMARELO}🛡️ Configurando limites de processos (Anti-ForkBomb)...${NC}"
cat <<'EOF' > /etc/security/limits.d/99-vpn-limits.conf
* soft    nproc           100
* hard    nproc           150
* soft    nofile          1024
* hard    nofile          2048
root            soft    nproc           unlimited
root            hard    nproc           unlimited
EOF
echo "$ADM_USER       soft    nproc           unlimited" >> /etc/security/limits.d/99-vpn-limits.conf
echo "$ADM_USER       hard    nproc           unlimited" >> /etc/security/limits.d/99-vpn-limits.conf
if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

# --- Habilita a tun0
sed -i 's/MaxBandwidth 100/MaxBandwidth 1000/' /etc/vnstat.conf
sed -i 's/UpdateInterval 30/UpdateInterval 5/' /etc/vnstat.conf
sed -i 's/SaveInterval 5/SaveInterval 1/' /etc/vnstat.conf
systemctl restart vnstat
# --- 9. Adicionado tun0 ao monitoramento do vnstat ---
if ip link show tun0 > /dev/null 2>&1; then
    vnstat -i tun0 --add
    systemctl restart vnstat
fi

# --- 10. Inicialização do guardião ---
echo -e "${AMARELO}🚀 Ativando Guardião...${NC}"
pkill -f "guardiao.sh" > /dev/null 2>&1 || true
nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ SISTEMA INSTALADO E LIBERADO!${NC}"
echo -e "    Administrador: ${AMARELO}$ADM_USER${NC}"
echo -e "    ${VERDE}Acesso SSH por senha: ATIVADO${NC}"
echo -e "${AZUL}===============================================================${NC}"
