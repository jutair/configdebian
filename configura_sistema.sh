#!/bin/bash
# instala_tudo.sh - Instalação completa OpenVPN + Configuração de Sistema

# --- VARIÁVEIS ---
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
DIR_CONFIG="/home/jutair/configdebian-main"
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# 1. VERIFICAÇÃO DE ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute como ROOT (sudo).${NC}"
  exit 1
fi

# 2. INSTALAÇÃO DE DEPENDÊNCIAS
echo -e "${AMARELO}Instalando pacotes base...${NC}"
apt update && apt upgrade -y
apt install sudo htop net-tools nload speedtest-cli vnstat bc curl unzip ufw fail2ban -y

# 3. INSTALAÇÃO AUTOMÁTICA OPENVPN (ANGRISTAN)
echo -e "${AMARELO}Iniciando instalação do OpenVPN...${NC}"
INSTALLER="openvpn-install.sh"
if [ ! -f "$INSTALLER" ]; then
    curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x "$INSTALLER"
fi

# Variáveis para instalação automática (Porta 1194 UDP)
export APPROVE_INSTALL=${APPROVE_INSTALL:-y}
export ENDPOINT=$(curl -4 -s ifconfig.me)
export PORT="1194"
export PROTOCOL="1" # UDP
export DNS="9"      # Google
export COMPRESSION="n"
export CUSTOMIZE_ENC="n"
export CLIENT="vpn_admin"
export PASS="1"

./$INSTALLER

# 4. OTIMIZAÇÃO DE LOGS (MONITOR DE MB)
echo -e "${AMARELO}Otimizando logs para monitoramento em tempo real...${NC}"

CONF_FILE="/etc/openvpn/server/server.conf"
LOG_FILE="/etc/openvpn/server/openvpn-status.log"

if [ -f "$CONF_FILE" ]; then
    # 1. Remove qualquer linha de status ou status-version existente para evitar conflito
    sed -i '/^status /d' "$CONF_FILE"
    sed -i '/^status-version/d' "$CONF_FILE"
    
    # 2. Adiciona as configurações otimizadas
    # O '5' no final indica que o log será atualizado a cada 5 segundos
    echo "status $LOG_FILE 5" >> "$CONF_FILE"
    echo "status-version 2" >> "$CONF_FILE"
    
    # 3. Garante que o arquivo de log exista e tenha permissões
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # 4. Reinicia o serviço para aplicar
    systemctl restart openvpn-server@server
    echo -e "${VERDE}✅ Logs do OpenVPN configurados com sucesso!${NC}"
else
    echo -e "${VERMELHO}❌ Erro: Arquivo $CONF_FILE não encontrado.${NC}"
fi

# Extra: Garantir que o VnStat monitore a interface correta desde o início
echo -e "${AMARELO}Iniciando monitoramento de tráfego (VnStat)...${NC}"
systemctl enable vnstat
systemctl start vnstat
systemctl restart openvpn-server@server

# 5. CONFIGURAÇÃO DE FIREWALL (UFW)
echo -e "${AMARELO}Configurando Firewall...${NC}"
ufw allow 22/tcp
ufw allow 1194/udp
ufw allow 53
echo "y" | ufw enable

# 6. FUNÇÃO DE PERFIL DE USUÁRIO
configurar_perfil() {
    local USER=$1; local SENHA=$2; local ADMIN=$3
    echo -e "${VERDE}Configurando usuário: $USER...${NC}"
    useradd -m -s /bin/bash "$USER" 2>/dev/null
    echo "$USER:$SENHA" | chpasswd
    [ "$ADMIN" = "true" ] && usermod -aG sudo "$USER"
    
    mkdir -p "/home/$USER/"{Backup,clientes_ovp,transfer,configdebian-main}
    
    # Copia scripts se existirem na pasta atual
    cp *.sh "/home/$USER/configdebian-main/" 2>/dev/null
    
    chown -R "$USER:$USER" "/home/$USER"
    chmod -R +x "/home/$USER/configdebian-main/"*.sh
}

# 7. CRIAÇÃO DOS USUÁRIOS
configurar_perfil "jutair" "SUA_SENHA_AQUI" "true"
configurar_perfil "guest" "SENHA_GUEST_AQUI" "false"

# 8. REGRAS DE SUDOERS
echo "jutair ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
echo "guest ALL=(ALL) NOPASSWD: /home/guest/configdebian-main/*.sh" >> /etc/sudoers

# 9. MENU NO LOGIN
cat <<EOF > /etc/profile.d/vpn_menu.sh
if [[ -t 0 ]]; then
    if [ -f "\$HOME/configdebian-main/menu.sh" ]; then
        sudo -E bash "\$HOME/configdebian-main/menu.sh"
    fi
fi
EOF
chmod +x /etc/profile.d/vpn_menu.sh

echo -e "${VERDE}***************************************************${NC}"
echo -e "${VERDE}   INSTALAÇÃO CONCLUÍDA COM SUCESSO!               ${NC}"
echo -e "${VERDE}***************************************************${NC}"
