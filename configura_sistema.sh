#!/bin/bash
# configura_sistema.sh - Configura sistema, copia chave SSH do root e inicia menu automaticamente
# Atualizado: 24-12-2025

set -e

USERS=("jutair" "guest")
DIR_DESTINO="/opt/configdebian"

echo "🔧 Configurando sistema..."

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

# 1️⃣ Instala pacotes essenciais
apt-get update
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo unzip wget curl

# 2️⃣ Criação de usuários e configuração de ambiente
for USERNAME in "${USERS[@]}"; do
    USER_HOME="/home/$USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        echo "👤 Criando usuário $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
    fi

    # Pastas do usuário
    mkdir -p "$USER_HOME"/{Backup,clientes_ovp,transfer}
    chown -R "$USERNAME:$USERNAME" "$USER_HOME"

    # 3️⃣ Copia a chave SSH do root, se existir
    if [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p "$USER_HOME/.ssh"
        cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
        chmod 700 "$USER_HOME/.ssh"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
    fi

    # 4️⃣ Configura .bashrc para iniciar menu.sh automaticamente
    cat <<'EOF' > "$USER_HOME/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF

    # 5️⃣ Configura .profile para carregar .bashrc
    cat <<'EOF' > "$USER_HOME/.profile"
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

# 6️⃣ Permite sudo sem senha
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 7️⃣ Criação da pasta global /opt/configdebian se não existir
mkdir -p "$DIR_DESTINO"

# 8️⃣ Baixa openvpn-install.sh do Angristan
echo "📥 Baixando openvpn-install.sh para $DIR_DESTINO..."
wget -q https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh -O "$DIR_DESTINO/openvpn-install.sh"

# 9️⃣ Ajusta permissões de todos os scripts
chown -R root:sudo "$DIR_DESTINO"
chmod -R 775 "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh

echo "✅ Configuração finalizada!"
echo "Usuários jutair e guest logarão via chave SSH do root e menu iniciará automaticamente."
