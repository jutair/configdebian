#!/bin/bash
# setup_vps.sh - Instalador de Segurança e Gestão VPS
# Versão: 26-12-2025
set -e

DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "setup_vps.sh" "guardiao.sh" "login.sh")

AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root.${NC}"
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           ${VERDE}INSTALADOR DE SEGURANÇA E GESTÃO VPS${NC}"
echo -e "                SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 1. Pergunta sobre Telegram
mkdir -p "$DIR_PROT"
echo -e "${AMARELO}🔔 CONFIGURAÇÃO DE ALERTAS TELEGRAM${NC}"
read -p "Deseja configurar os alertas do Telegram agora? (s/n): " CONF_TEL
if [[ "$CONF_TEL" =~ ^[Ss]$ ]]; then
    read -p " Token do Bot: " TOKEN
    read -p " ID do Chat: " ID_CHAT
    echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
    echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"
    echo -e "${VERDE}✅ Configurações de alerta salvas.${NC}"
else
    echo -e "${AMARELO}⚠ Alertas não configurados. Você pode configurar manualmente em $DIR_PROT/telegram.conf posteriormente.${NC}"
    touch "$DIR_PROT/telegram.conf"
fi
echo -e "${AZUL}---------------------------------------------------------------${NC}"

# 2. Coleta de dados dos Usuários
read -p " Nome para o usuário ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o usuário OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# 3. Criação de Estrutura e Permissões
mkdir -p "$DIR_CONFIG"
echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/config.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/config.conf"
chmod 700 "$DIR_PROT"
chmod 600 "$DIR_PROT/*.conf" 2>/dev/null || true

# 4. Habilitar Login por Senha no SSH (Resolve o erro de Permission Denied)
echo -e "${AMARELO}🔓 Ajustando configurações de acesso SSH...${NC}"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

# 5. Instalação de Pacotes
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc unzip procps

# 6. Download dos Scripts
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    curl -fsSL "$GITHUB_REPO/$SCRIPT" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# 7. Criação de Usuários
echo -e "${AMARELO}👤 Criando contas de acesso...${NC}"
for USUARIO in "$ADM_USER" "$OPE_USER"; do
    if ! id "$USUARIO" &>/dev/null; then
        useradd -m -s /bin/bash "$USUARIO"
        [ "$USUARIO" == "$ADM_USER" ] && SENHA="$ADM_PASS" || SENHA="$OPE_PASS"
        echo "$USUARIO:$SENHA" | chpasswd
    fi
done
usermod -aG sudo "$ADM_USER"

# Sudoers sem senha para o Menu
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 8. Blindagem PAM e Profile
echo -e "${AMARELO}🛡️  Aplicando travas de segurança...${NC}"
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so /opt/configdebian/login.sh" >> /etc/pam.d/sshd

sed -i '/menu.sh/d' /etc/profile
echo '[ -f /opt/configdebian/menu.sh ] && exec bash /opt/configdebian/menu.sh' >> /etc/profile

# 9. Inicialização do Guardião
echo -e "${AMARELO}🚀 Ativando Guardião...${NC}"
pkill -f "guardiao.sh" > /dev/null 2>&1 || true
nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ SISTEMA INSTALADO E BLINDADO COM SUCESSO!${NC}"
echo -e "${AZUL}===============================================================${NC}"
echo -e "Usuário Admin: ${AMARELO}$ADM_USER${NC}"
echo -e "Usuário Operador: ${AMARELO}$OPE_USER${NC}"
echo -e "${AZUL}===============================================================${NC}"
