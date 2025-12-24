#!/bin/bash
# setup_vps.sh - Setup inicial da VPS (root)
# Integrado com configura_sistema.sh para login SSH com chave e menu automático

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root"
    exit 1
fi

echo "🔧 Iniciando setup da VPS..."

# 1️⃣ Instala dependências básicas
apt-get update
apt-get install -y wget unzip curl sudo

# 2️⃣ Limpeza de instalações anteriores
rm -rf /opt/configdebian
rm -rf /tmp/configdebian-main*
rm -f /tmp/main.zip

# 3️⃣ Baixa repositório
echo "📥 Baixando repositório configdebian..."
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# 4️⃣ Extrai e move para /opt/configdebian
echo "📂 Extraindo arquivos..."
unzip -q -o /tmp/main.zip -d /tmp/
mkdir -p /opt/configdebian
mv /tmp/configdebian-main/* /opt/configdebian/
chmod +x /opt/configdebian/*.sh
rm -f /tmp/main.zip

# 5️⃣ Cria o configura_sistema.sh com chave pública integrada
cat <<'EOF' > /opt/configdebian/configura_sistema.sh
#!/bin/bash
set -e
USERS=("jutair" "guest")
DIR_DESTINO="/opt/configdebian"
# Substitua pelo conteúdo da sua chave pública SSH
PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... SEU_EMAIL"

echo "🔧 Configurando sistema..."

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root."
    exit 1
fi

apt-get update
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo

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

    mkdir -p "$USER_HOME/.ssh"
    echo "$PUBKEY" > "$USER_HOME/.ssh/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"

    cat <<'BASHRC' > "$USER_HOME/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
BASHRC

    cat <<'PROFILE' > "$USER_HOME/.profile"
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
PROFILE

    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

chown -R root:sudo "$DIR_DESTINO"
chmod -R 775 "$DIR_DESTINO"
chmod +x "$DIR_DESTINO"/*.sh

echo "✅ Configuração finalizada! Usuários jutair e guest logarão com a chave SSH e menu será iniciado automaticamente."
EOF

chmod +x /opt/configdebian/configura_sistema.sh

# 6️⃣ Executa o configurador
echo "⚙️ Executando configura_sistema.sh..."
bash /opt/configdebian/configura_sistema.sh

echo "✅ Setup VPS finalizado!"
echo "➡ Faça login com jutair ou guest via chave SSH. O menu iniciará automaticamente."
