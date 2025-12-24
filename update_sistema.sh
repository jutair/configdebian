#!/bin/bash
# update_sistema.sh - Atualiza sistema e scripts configdebian
# Atualizado: 24-12-2025 v2

set -e

DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/seuusuario/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"

echo "🔧 Iniciando atualização do sistema e scripts..."

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

# 1️⃣ Atualiza o sistema
echo "⏳ Atualizando sistema..."
apt-get update && apt-get upgrade -y
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# 2️⃣ Cria pasta configdebian se não existir
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# 3️⃣ Lista de scripts principais para baixar
SCRIPTS=(
    "menu.sh"
    "open_vpn_conf.sh"
    "gerencia_rede.sh"
    "usuarios.sh"
    "configura_sistema.sh"
    "backup.sh"
)

for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"

    # Backup do script antigo, se existir
    if [ -f "$DEST" ]; then
        cp "$DEST" "$DEST.bak_$(date +%Y%m%d_%H%M%S)"
        echo "⚠ Backup criado para $SCRIPT"
    fi

    # Baixa o script do GitHub
    echo "⏳ Baixando $SCRIPT..."
    if curl -fsSL "$URL" -o "$DEST"; then
        chmod +x "$DEST"
        chown root:sudo "$DEST"
        echo "✔ $SCRIPT atualizado com sucesso"
