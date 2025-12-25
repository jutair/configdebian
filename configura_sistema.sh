#!/bin/bash
# configura_sistema.sh - Configura sistema, usuários e scripts configdebian
# Atualizado: 24-12-2025

set -e

USERS=("jutair" "guest")
DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "configura_sistema.sh" "autokil.sh")

# --- Verifica ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

echo "🔧 Atualizando sistema e instalando pacotes essenciais..."
apt-get update
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# --- Cria pasta global configdebian ---
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# --- Baixa scripts principais do GitHub ---
echo "⏳ Baixando scripts configdebian..."
for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"
    curl -fsSL "$URL" -o "$DEST" || echo "⚠ Falha ao baixar $SCRIPT"
    chmod +x "$DEST"
    chown root:sudo "$DEST"
done

# --- Baixa openvpn-install.sh oficial ---
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DIR_CONFIG/$OPENVPN_SCRIPT"
chmod +x "$DIR_CONFIG/$OPENVPN_SCRIPT"
chown root:sudo "$DIR_CONFIG/$OPENVPN_SCRIPT"

# --- Criação de usuários e configuração automática ---
for USERNAME in "${USERS[@]}"; do
    USER_HOME="/home/$USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        echo "👤 Criando usuário $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
    fi

    mkdir -p "$USER_HOME"/{Backup,clientes_ovp,transfer}
    chown -R "$USERNAME:$USERNAME" "$USER_HOME"

    # Copia chave SSH do root
    if [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p "$USER_HOME/.ssh"
        cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
        chmod 700 "$USER_HOME/.ssh"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
    fi

    # Configura .bashrc para iniciar menu automaticamente
    cat <<'EOF' > "$USER_HOME/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF

    # Configura .profile para carregar .bashrc
    cat <<'EOF' > "$USER_HOME/.profile"
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

# --- Permite sudo sem senha ---
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# --- Permissões da pasta global ---
chmod -R 775 "$DIR_CONFIG"
chmod +x "$DIR_CONFIG"/*.sh
chown -R root:sudo "$DIR_CONFIG"
echo "✅ Usuários jutair e guest logarão diretamente no menu."
echo "⌛ Aplicando as proteções de segurança..."
# ... (seu código anterior de limites e sysctl) ...

# Aplicar as mudanças de Kernel imediatamente
sysctl -p /etc/sysctl.d/99-vps-security.conf
echo "⌛ Aplicando as proteções de segurança..."
# ===============================================================
# 4. ATIVAÇÃO DO MONITOR DE INTEGRIDADE (AUTO-KILL)
# ===============================================================
echo -e "${AZUL}Ativando o monitor de integridade (Auto-Kill)...${NC}"

# Garante que o diretório e o script existem e têm permissão
if [ -f "/opt/configdebian/autokil.sh" ]; then
    chmod +x /opt/configdebian/autokil.sh
    
    # 1. REMOVE DO CRONTAB (O script agora tem loop próprio de 10s)
    # Deixar no crontab causaria múltiplas instâncias travando sua CPU
    crontab -l 2>/dev/null | grep -v "autokil.sh" | crontab -
    
    # 2. LIMPEZA DE SEGURANÇA
    # Mata qualquer processo antigo que possa ter restado de uma instalação anterior
    pkill -f "autokil.sh" > /dev/null 2>&1
    
    # 3. INICIALIZAÇÃO DO LOG
    touch /var/log/vps_autokill.log
    chmod 644 /var/log/vps_autokill.log
    
    # 4. INICIALIZAÇÃO IMEDIATA (DAEMON MODE)
    # O "nohup" permite que o script continue rodando mesmo após você sair do SSH
    # O "&" joga para segundo plano imediatamente
    nohup /bin/bash /opt/configdebian/autokil.sh > /dev/null 2>&1 &
    
    echo -e "${VERDE}✅ Monitoramento ativado e rodando em tempo real (10s)!${NC}"
else
    echo -e "${VERMELHO}⚠️ Alerta: /opt/configdebian/autokil.sh não encontrado!${NC}"
fi
echo "✅ Usuários jutair e guest logarão diretamente no menu."
