#!/bin/bash
# update_sistema.sh - Atualiza sistema e scripts configdebian
# Versão: 24-12-2025 robusta

set -e

DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/seuusuario/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"

# --- Cores ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

echo -e "${AZUL}🔧 Iniciando atualização do sistema e scripts...${NC}"

# Verifica ROOT
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Execute este script como root.${NC}"
    exit 1
fi

# 1️⃣ Atualiza o sistema
echo -e "${AZUL}⏳ Atualizando sistema...${NC}"
apt-get update && apt-get upgrade -y
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# 2️⃣ Cria pasta configdebian se não existir
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# 3️⃣ Função para baixar scripts
baixar_script() {
    local URL="$1"
    local DEST="$2"

    # Backup do arquivo antigo, se existir
    if [ -f "$DEST" ]; then
        cp "$DEST" "$DEST.bak_$(date +%Y%m%d%H%M%S)"
        echo -e "${AMARELO}⚠ Backup criado para $(basename "$DEST")${NC}"
    fi

    # Baixa o arquivo
    curl -fsSL "$URL" -o "$DEST"
    if [ ! -s "$DEST" ]; then
        echo -e "${VERMELHO}❌ Falha ao baixar $(basename "$DEST")${NC}"
        return 1
    fi
    chmod +x "$DEST"
    chown root:sudo "$DEST"
    echo -e "${VERDE}✔ $(basename "$DEST") atualizado com sucesso!${NC}"
}

# 4️⃣ Baixa scripts principais do GitHub
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "configura_sistema.sh")

for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"
    echo -e "${AZUL}⏳ Baixando $SCRIPT...${NC}"
    baixar_script "$URL" "$DEST"
done

# 5️⃣ Baixa o openvpn-install.sh diretamente
URL_OVPN="https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT"
DEST_OVPN="$DIR_CONFIG/$OPENVPN_SCRIPT"
echo -e "${AZUL}⏳ Baixando $OPENVPN_SCRIPT...${NC}"
baixar_script "$URL_OVPN" "$DEST_OVPN"

# 6️⃣ Confere permissões da pasta e arquivos
chmod -R 775 "$DIR_CONFIG"
chmod +x "$DIR_CONFIG"/*.sh
chown -R root:sudo "$DIR_CONFIG"

echo -e "${VERDE}✅ Todos os scripts configdebian atualizados com sucesso!${NC}"
