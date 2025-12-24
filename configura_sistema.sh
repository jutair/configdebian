#!/bin/bash
# configura_sistema.sh - Configura sistema, usuários e atualiza scripts configdebian
# 24-12-2025

set -e

USERS=("jutair" "guest")
DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/seuusuario/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "configura_sistema.sh")

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
    curl -fsSL "$URL" -o "$DEST"
    chmod +x "$DEST"
done

# --- Baixa openvpn-install.sh oficial ---
echo "⏳ Baixando $OPENVPN_SCRIPT..."
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DIR_CONFIG/$OPENVPN_SCRIPT"
chmod +x "$DIR_CONFIG/$OPENVPN_SCRIPT"

# --- Criação de usuários e configuração ---
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
