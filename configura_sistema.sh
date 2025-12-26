#!/bin/bash
# configura_sistema.sh - Versão Final Consolidada
# Atualizado: 26-12-2025
set -e

DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "configura_sistema.sh" "guardiao.sh")

# Cores para o terminal
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Verifica se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root.${NC}"
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "          ${VERDE}INSTALADOR DE SEGURANÇA INTERATIVO${NC}"
echo -e "               SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 1. Coleta de dados (Interativo)
read -p " Nome para o usuário ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o usuário OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# 2. Criação de Pastas e Salvamento da Configuração
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"
echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/config.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/config.conf"
chmod 600 "$DIR_PROT/config.conf"

# 3. Instalação de Pacotes Essenciais
echo -e "${AMARELO}🔧 Instalando pacotes do sistema...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc unzip

# 4. Download dos Scripts do GitHub
echo -e "${AMARELO}⏳ Baixando ferramentas do repositório...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    curl -fsSL "$GITHUB_REPO/$SCRIPT" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# 5. Configuração do Administrador
if ! id "$ADM_USER" &>/dev/null; then
    echo -e "👤 Criando administrador: ${VERDE}$ADM_USER${NC}"
    useradd -m -s /bin/bash "$ADM_USER"
    echo "$ADM_USER:$ADM_PASS" | chpasswd
    usermod -aG sudo "$ADM_USER"
    
    cat <<'EOF' > "/home/$ADM_USER/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF
    chown "$ADM_USER:$ADM_USER" "/home/$ADM_USER/.bashrc"
fi

# 6. Configuração do Operador
if ! id "$OPE_USER" &>/dev/null; then
    echo -e "👤 Criando operador: ${VERDE}$OPE_USER${NC}"
    useradd -m -s /bin/bash "$OPE_USER"
    echo "$OPE_USER:$OPE_PASS" | chpasswd
    
    cat <<'EOF' > "/home/$OPE_USER/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF
    chown "$OPE_USER:$OPE_USER" "/home/$OPE_USER/.bashrc"
fi

# 7. Permissões de Sudo sem Senha (Para o Menu)
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 8. Inicialização do Guardião (Auto-Kill)
echo -e "${AMARELO}🛡️  Iniciando o Guardião do Sistema...${NC}"
if [ -f "$DIR_CONFIG/guardiao.sh" ]; then
    pkill -f "guardiao.sh" > /dev/null 2>&1 || true
    # Inicializa em segundo plano
    nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &
    echo -e "${VERDE}✅ Guardião em execução!${NC}"
fi

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ INSTALAÇÃO E CONFIGURAÇÃO CONCLUÍDAS!${NC}"
echo -e "${AZUL}===============================================================${NC}"
echo -e "Administrador: ${AMARELO}$ADM_USER${NC}"
echo -e "Operador: ${AMARELO}$OPE_USER${NC}"
echo -e "Log de Auto-Kill: /var/log/vps_autokill.log"
echo -e "${AZUL}===============================================================${NC}"
echo -e "${AZUL}===============================================================${NC}"
echo -e "   ${VERDE}✅ AGORA JÁ PODE LOGAR COM OS NOVOS USUÁRIOS CRIADOS!${NC}"
echo -e "${AZUL}===============================================================${NC}"
