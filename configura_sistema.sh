#!/bin/bash
# configura_sistema.sh - Configuração final do sistema + menu automático

set -e

USERS=("jutair" "guest")
DIR_DESTINO="/opt/configdebian"
REPO_ZIP_URL="https://github.com/jutair/configdebian/archive/refs/heads/main.zip"
TMP_ZIP="/tmp/main.zip"

echo "🔧 Iniciando configuração do sistema..."

# 1️⃣ Roda como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

# 2️⃣ Instala dependências essenciais
apt-get update
apt-get install -y sudo curl unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 3️⃣ Limpa instalações anteriores
rm -rf "$DIR_DESTINO"
rm -rf /tmp/configdebian-main
rm -f "$TMP_ZIP"

# 4️⃣ Baixa e extrai repositório
echo "📥 Baixando repositório..."
wget -q "$REPO_ZIP_URL" -O "$TMP_ZIP"
unzip -q -o "$TMP_ZIP" -d /tmp/
mv /tmp/configdebian-main "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh
rm -f "$TMP_ZIP"

# 5️⃣ Criação de usuários e configuração de ambiente
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

    # Configura .bashrc para iniciar menu.sh
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

# 6️⃣ Sudo sem senha
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 7️⃣ Permissões na pasta global
chown -R root:sudo "$DIR_DESTINO"
chmod -R 775 "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh

echo "✅ Configuração finalizada! Usuários logarão diretamente no menu."
