#!/bin/bash
# configura_sistema.sh - Configura sistema e login automático do menu

set -e

USERS=("jutair" "guest")
DIR_DESTINO="/opt/configdebian"

echo "🔧 Configurando sistema..."

# Roda como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

# Instala pacotes essenciais
apt-get update
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo

# Criação de usuários e configuração de ambiente
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

    # Configura .bashrc para iniciar menu.sh no login
    cat <<'EOF' > "$USER_HOME/.bashrc"
# ~/.bashrc gerenciado pelo configdebian
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF

    # Configura .profile para login SSH carregar .bashrc
    cat <<'EOF' > "$USER_HOME/.profile"
# ~/.profile gerenciado pelo configdebian
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

# Sudo sem senha
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# Permissões na pasta global
chown -R root:sudo "$DIR_DESTINO"
chmod -R 775 "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh

echo "✅ Configuração finalizada! Usuários logarão diretamente no menu."
