#!/bin/bash
# update_sistema.sh - Atualiza sistema e scripts configdebian
# 24-12-2025

set -e

# --- CONFIGURAÇÃO ---
DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"  # Substitua pelo seu usuário/repos
OPENVPN_SCRIPT="openvpn-install.sh"

echo "🔧 Iniciando atualização do sistema e scripts..."

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

# --- 1️⃣ Atualiza o sistema ---
echo "⏳ Atualizando sistema..."
apt-get update && apt-get upgrade -y
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# --- 2️⃣ Cria pasta configdebian se não existir ---
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# --- 3️⃣ Baixa scripts principais do GitHub ---
echo "⏳ Baixando scripts do GitHub..."
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "configura_sistema.sh")

for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"

    if [ -f "$DEST" ]; then
        cp "$DEST" "${DEST}.bak"
        echo "⚠ Backup criado para $SCRIPT"
    fi

    echo "⏳ Baixando $SCRIPT..."
    curl -fsSL "$URL" -o "$DEST" || { echo "❌ Falha ao baixar $SCRIPT"; continue; }
    chmod +x "$DEST"
done

# --- 4️⃣ Baixa o openvpn-install.sh diretamente ---
echo "⏳ Baixando $OPENVPN_SCRIPT..."
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DIR_CONFIG/$OPENVPN_SCRIPT"
chmod +x "$DIR_CONFIG/$OPENVPN_SCRIPT"

# --- 5️⃣ Confere permissões ---
chmod +x "$DIR_CONFIG"/*.sh
chown root:sudo "$DIR_CONFIG"/*.sh

echo "✅ Scripts configdebian atualizados com sucesso!"
