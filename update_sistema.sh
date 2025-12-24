#!/bin/bash
# update_sistema.sh - Atualiza sistema e scripts configdebian
# Atualizado: 24-12-2025

set -e

DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/seuusuario/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "configura_sistema.sh" "backup.sh" "update_sistema.sh")

# --- Verifica ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

echo "🔧 Iniciando atualização do sistema e scripts..."

# --- 1️⃣ Atualiza sistema e instala pacotes essenciais ---
echo "⏳ Atualizando sistema..."
apt-get update
apt-get upgrade -y
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# --- 2️⃣ Cria pasta configdebian se não existir ---
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# --- 3️⃣ Baixa scripts principais do GitHub com backup ---
echo "⏳ Baixando scripts do GitHub..."
for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"

    # Faz backup se o script já existir
    if [ -f "$DEST" ]; then
        cp "$DEST" "$DEST.bak_$(date +%Y%m%d_%H%M%S)"
        echo "⚠ Backup criado para $SCRIPT"
    fi

    if curl -fsSL "$URL" -o "$DEST"; then
        chmod +x "$DEST"
        chown root:sudo "$DEST"
        echo "✔ $SCRIPT atualizado"
    else
        echo "❌ Falha ao baixar $SCRIPT. Mantendo versão anterior (se existir)."
    fi
done

# --- 4️⃣ Baixa openvpn-install.sh oficial ---
DEST_OVPN="$DIR_CONFIG/$OPENVPN_SCRIPT"
if [ -f "$DEST_OVPN" ]; then
    cp "$DEST_OVPN" "$DEST_OVPN.bak_$(date +%Y%m%d_%H%M%S)"
    echo "⚠ Backup criado para $OPENVPN_SCRIPT"
fi
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DEST_OVPN"
chmod +x "$DEST_OVPN"
chown root:sudo "$DEST_OVPN"
echo "✔ $OPENVPN_SCRIPT atualizado"

# --- 5️⃣ Confere permissões gerais ---
chmod -R 775 "$DIR_CONFIG"
chmod +x "$DIR_CONFIG"/*.sh
chown -R root:sudo "$DIR_CONFIG"

echo "✅ Scripts configdebian atualizados com sucesso!"
