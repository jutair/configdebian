#!/bin/bash
# configura_sistema.sh - Instalador de Segurança e Gestão VPS
# Atualizado: 26-12-2025
set -e

# --- CONFIGURAÇÕES ---
DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
# Adicionado login.sh à lista
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "configura_sistema.sh" "guardiao.sh" "login.sh")

# Cores para o terminal
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Verifica se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root.${NC}"
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           ${VERDE}INSTALADOR DE SEGURANÇA E GESTÃO VPS${NC}"
echo -e "                SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 1. Coleta de Dados do Telegram (Obrigatório para Alertas)
echo -e "${AMARELO}Configuração de Alertas Telegram:${NC}"
read -p " Token do Bot: " TOKEN
read -p " ID do Chat: " ID_CHAT
echo -e "${AZUL}---------------------------------------------------------------${NC}"

# 2. Coleta de dados dos Usuários
read -p " Nome para o usuário ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o usuário OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# 3. Criação de Pastas e Configurações
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"
echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/config.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/config.conf"
echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"
chmod 600 "$DIR_PROT/*.conf"

# 4. Instalação de Pacotes
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc unzip procps

# 5. Download e Permissões dos Scripts
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    curl -fsSL "$GITHUB_REPO/$SCRIPT" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# 6. Criação de Usuários e Sudoers
echo -e "${AMARELO}👤 Configurando contas de acesso...${NC}"
for USUARIO in "$ADM_USER" "$OPE_USER"; do
    if ! id "$USUARIO" &>/dev/null; then
        useradd -m -s /bin/bash "$USUARIO"
        [ "$USUARIO" == "$ADM_USER" ] && SENHA="$ADM_PASS" || SENHA="$OPE_PASS"
        echo "$USUARIO:$SENHA" | chpasswd
    fi
done
usermod -aG sudo "$ADM_USER"

# Permissão sudo sem senha para o menu rodar comandos de sistema
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 7. BLINDAGEM DO SISTEMA (PAM & PROFILE)
echo -e "${AMARELO}🛡️  Aplicando travas de segurança...${NC}"

# Configura Alerta de Login Instantâneo (login.sh)
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so /opt/configdebian/login.sh" >> /etc/pam.d/sshd

# Configura Jaula de Usuário (Profile) - Força o menu no login e impede terminal
sed -i '/menu.sh/d' /etc/profile
echo '[ -f /opt/configdebian/menu.sh ] && exec bash /opt/configdebian/menu.sh' >> /etc/profile

# 8. INICIALIZAÇÃO DO GUARDIÃO
echo -e "${AMARELO}🚀 Ativando Guardião (Monitor de Shell e Recursos)...${NC}"
pkill -f "guardiao.sh" > /dev/null 2>&1 || true
nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ SISTEMA INSTALADO E BLINDADO COM SUCESSO!${NC}"
echo -e "${AZUL}===============================================================${NC}"
echo -e "Administrador: ${AMARELO}$ADM_USER${NC}"
echo -e "Operador: ${AMARELO}$OPE_USER${NC}"
echo -e "Alertas: ${VERDE}Ativos via Telegram${NC}"
echo -e "${AZUL}===============================================================${NC}"
