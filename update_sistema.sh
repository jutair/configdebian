#!/bin/bash
# update_sistema.sh - Atualização segura do sistema e scripts configdebian
# Versão estável - 24-12-2025

set -e

DIR_CONFIG="/opt/configdebian"
BACKUP_DIR="/opt/configdebian/backups"
DATA=$(date +"%Y%m%d-%H%M%S")

GITHUB_BASE="https://raw.githubusercontent.com/jutair/configdebian/main"

SCRIPTS=(
  menu.sh
  open_vpn_conf.sh
  gerencia_rede.sh
  usuarios.sh
  configura_sistema.sh
  backup.sh
  update_sistema.sh
)

AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# ---------------- ROOT ----------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Execute como root ou com sudo${NC}"
    exit 1
fi

echo -e "${AZUL}🔄 Atualizando sistema...${NC}"

apt-get update
apt-get upgrade -y
apt-get install -y openvpn samba speedtest-cli bc sudo curl wget unzip vnstat ufw fail2ban

# ---------------- BACKUP ----------------
mkdir -p "$BACKUP_DIR/$DATA"

echo -e "${AZUL}📦 Criando backups...${NC}"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$DIR_CONFIG/$script" ]; then
        cp "$DIR_CONFIG/$script" "$BACKUP_DIR/$DATA/"
    fi
done

# ---------------- DOWNLOAD ----------------
echo -e "${AZUL}⏳ Baixando scripts do GitHub...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"

    echo -ne "${AMARELO}→ $script ... ${NC}"

    # Testa se o arquivo existe no GitHub
    if curl -fsI "$URL" >/dev/null; then
        curl -fsSL "$URL" -o "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}atualizado${NC}"
    else
        echo -e "${VERMELHO}404 (mantido local)${NC}"
    fi
done

# ---------------- LIMPEZA ----------------
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

# ---------------- FINAL ----------------
echo -e "${VERDE}✅ Atualização concluída com sucesso!${NC}"
echo -e "${AZUL}📂 Backups em:${NC} $BACKUP_DIR/$DATA"
echo -e "${AZUL}➡️ Retorne ao menu para aplicar as mudanças.${NC}"

exit 0
