#!/bin/bash
# configura_sistema.sh - Configura sistema, usuários e atualiza scripts configdebian
# Atualizado: 24-12-2025 v2

set -e

USERS=("jutair" "guest")
DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/seuusuario/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "configura_sistema.sh" "backup.sh")

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
    
    # Backup se existir
    [ -f "$DEST" ] && cp "$DEST" "$DEST.bak_$(date +%Y%m%d_%H%M%S)" && echo "⚠ Backup criado para $SCRIPT"
    
    if curl -fsSL "$URL" -o "$DEST"; then
        chmod +x "$DEST"
        chown root:sudo "$DEST"
        echo "✔ $SCRIPT atualizado"
    else
        echo "❌ Falha ao baixar $SCRIPT. Mantendo versão anterior (se existir)."
    fi
done

# --- Baixa openvpn-install.sh oficial ---
DEST_OVPN="$DIR_CONFIG/$OPENVPN_SCRIPT"
[ -f "$DEST_OVPN" ] && cp "$DEST_OVPN" "$DEST_OVPN.bak_$(date +%Y%m%d_%H%M%S)" && echo "⚠ Backup criado para $OPENVPN_SCRIPT"
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DEST_OVPN"
chmod +x "$DEST_OVPN"
chown root:sudo "$DEST_OVPN"
echo "✔ $OPENVPN_SCRIPT atualizado"

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

# --- Permite sudo sem senha para grupo sudo ---
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# --- Permissões da pasta global configdebian ---
chmod -R 775 "$DIR_CONFIG"
chmod +x "$DIR_CONFIG"/*.sh
chown -R root:sudo "$DIR_CONFIG"

echo "✅ Configuração finalizada! Usuários jutair e guest logarão via chave SSH do root e menu iniciará automaticamente."
