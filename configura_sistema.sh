#!/bin/bash
# configura_sistema.sh - Configuração do sistema + menu automático

set -e

### VARIÁVEIS ###
USERS=("jutair" "guest")
DIR_DESTINO="/opt/configdebian"
REPO_ZIP_URL="https://github.com/jutair/configdebian/archive/refs/heads/main.zip"
TMP_ZIP="/tmp/main.zip"
TMP_DIR="/tmp/configdebian-main"

echo "🔧 Iniciando configuração do sistema..."

### 1️⃣ GARANTE QUE O SCRIPT RODE COMO ROOT ###
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

### 2️⃣ INSTALA DEPENDÊNCIAS BÁSICAS ###
echo "📦 Instalando pacotes essenciais..."
apt-get update
apt-get install -y sudo curl unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

### 3️⃣ LIMPA CONFIGURAÇÕES ANTIGAS ###
rm -rf "$DIR_DESTINO"
rm -rf "$TMP_DIR"
rm -f "$TMP_ZIP"

### 4️⃣ BAIXA REPOSITÓRIO E MOVE PARA /OPT ###
echo "📥 Baixando repositório..."
wget -q "$REPO_ZIP_URL" -O "$TMP_ZIP"
unzip -q -o "$TMP_ZIP" -d /tmp/
mv /tmp/configdebian-main "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh
rm -f "$TMP_ZIP"

echo "📁 Repositório instalado em $DIR_DESTINO"

### 5️⃣ CRIAÇÃO DE USUÁRIOS E CONFIGURAÇÃO DE AMBIENTE ###
for USERNAME in "${USERS[@]}"; do
    USER_HOME="/home/$USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        echo "👤 Criando usuário $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
    else
        echo "👤 Usuário $USERNAME já existe."
    fi

    # Pastas do usuário
    mkdir -p "$USER_HOME"/{Backup,clientes_ovp,transfer}
    chown -R "$USERNAME:$USERNAME" "$USER_HOME"

    # Configura .bashrc para chamar menu.sh
    cat <<'EOF' > "$USER_HOME/.bashrc"
# ~/.bashrc - gerenciado pelo configdebian

# Não executa em shell não interativo
[[ $- != *i* ]] && return

# Proteção contra loop
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF

    # Configura .profile para carregar .bashrc no login SSH
    cat <<'EOF' > "$USER_HOME/.profile"
# ~/.profile - gerenciado pelo configdebian

if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

    # Permissões corretas
    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

### 6️⃣ PERMISSÕES DE SUDO ###
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

### 7️⃣ PERMISSÕES NA PASTA GLOBAL ###
chown -R root:sudo "$DIR_DESTINO"
chmod -R 775 "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh

echo "✅ Configuração finalizada com sucesso!"
echo "➡ Ao logar via SSH com os usuários, o menu será iniciado automaticamente."
