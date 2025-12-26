#!/bin/bash
# setup_vps.sh - Instalador de Segurança e Gestão VPS
# Atualizado: 26-12-2025
# --- CORES ---
VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; NC='\033[0m'

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

# --- RESTO DO CÓDIGO ---
echo "Agora eu tenho certeza que sou ROOT!"
set -e

# --- CONFIGURAÇÕES ---
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

# 1. Coleta de Dados
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

# 2. Criação das Pastas (IMPORTANTE: Antes de gravar os arquivos)
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"

# 3. Gravação dos Arquivos de Configuração
echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/config.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/config.conf"
echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"

# 4. Aplicação de Permissões Restritas (Agora os arquivos já existem)
chmod 700 "$DIR_PROT"
chmod 600 "$DIR_PROT/config.conf"
chmod 600 "$DIR_PROT/telegram.conf"

# 5. Instalação de Pacotes
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc unzip procps

# 6. Download dos Scripts
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    # Se o nome no GitHub ainda for configura_sistema.sh, ajuste aqui:
    URL_DOWNLOAD="$GITHUB_REPO/$SCRIPT"
    # Pequeno ajuste caso o arquivo no GitHub tenha nome diferente do local
    curl -fsSL "$URL_DOWNLOAD" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# 7. Criação de Usuários
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
