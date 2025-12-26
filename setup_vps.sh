#!/bin/bash
# setup_vps.sh - Instalador de Segurança e Gestão VPS
# Versão Final Consolidada - 26-12-2025
set -e

# --- CONFIGURAÇÕES DE DIRETÓRIOS ---
DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "setup_vps.sh" "guardiao.sh" "login.sh")

# Cores
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Verificação de Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root.${NC}"
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           ${VERDE}INSTALADOR DE SEGURANÇA E GESTÃO VPS${NC}"
echo -e "                SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 1. COLETA DE DADOS (Interativo)
echo -e "${AMARELO}Configuração de Alertas Telegram:${NC}"
read -p " Token do Bot: " TOKEN
read -p " ID do Chat: " ID_CHAT
echo -e "${AZUL}---------------------------------------------------------------${NC}"
read -p " Nome para o usuário ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o usuário OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# 2. CRIAÇÃO DE ESTRUTURA
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"

# 3. SALVAMENTO DE CONFIGURAÇÕES (Correção de Permissão)
echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/config.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/config.conf"
echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"

chmod 700 "$DIR_PROT"
chmod 600 "$DIR_PROT/config.conf"
chmod 600 "$DIR_PROT/telegram.conf"

# 4. INSTALAÇÃO DE DEPENDÊNCIAS
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc unzip procps

# 5. DOWNLOAD DOS SCRIPTS DO GITHUB
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    curl -fsSL "$GITHUB_REPO/$SCRIPT" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# 6. CONFIGURAÇÃO DE USUÁRIOS
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

# 7. CONFIGURAÇÃO PAM (Alerta login.sh)
echo -e "${AMARELO}🛡️  Configurando PAM e Alertas de Sessão...${NC}"
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so /opt/configdebian/login.sh" >> /etc/pam.d/sshd

# 8. JAULA DE SHELL (Profile)
echo -e "${AMARELO}🛡️  Configurando Jaula de Shell (Menu)...${NC}"
sed -i '/menu.sh/d' /etc/profile
echo '[ -f /opt/configdebian/menu.sh ] && exec bash /opt/configdebian/menu.sh' >> /etc/profile

# 9. INICIALIZAÇÃO DO GUARDIÃO
echo -e "${AMARELO}🚀 Ativando Guardião...${NC}"
pkill -f "guardiao.sh" > /dev/null 2>&1 || true
nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ SISTEMA INSTALADO E BLINDADO COM SUCESSO!${NC}"
echo -e "${AZUL}===============================================================${NC}"
echo -e "Usuário Admin: ${AMARELO}$ADM_USER${NC}"
echo -e "Alertas Telegram: ${VERDE}Ativados${NC}"
echo -e "${AZUL}===============================================================${NC}"
