#!/bin/bash
# update_sistema.sh - Atualização segura e atômica
# Versão: 25-12-2025

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
  autokil.sh
)

# Cores para interface
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# 1. Verificação de ROOT
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root.${NC}"
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           🔄 ATUALIZAÇÃO INTELIGENTE DO SISTEMA"
echo -e "${AZUL}===============================================================${NC}"

# 2. Atualização de Repositórios e Pacotes
echo -e "${AMARELO}⌛ Atualizando pacotes do sistema...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y openvpn samba speedtest-cli bc sudo curl wget unzip vnstat ufw fail2ban

# 3. Backup de Segurança
mkdir -p "$BACKUP_DIR/$DATA"
echo -e "${AZUL}📦 Criando backup da versão atual...${NC}"
for script in "${SCRIPTS[@]}"; do
    [ -f "$DIR_CONFIG/$script" ] && cp "$DIR_CONFIG/$script" "$BACKUP_DIR/$DATA/"
done

# 4. Download Atômico (Substituição segura de arquivos)
echo -e "${AZUL}⏳ Sincronizando scripts com GitHub...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"
    TEMP="$DEST.tmp"

    echo -ne "${AMARELO}→ $script ... ${NC}"

    # Tenta baixar para o arquivo temporário
    if curl -fsSL "$URL" -o "$TEMP"; then
        # Se o download foi 100%, substitui o original e dá permissão
        mv "$TEMP" "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}OK!${NC}"
    else
        echo -e "${VERMELHO}FALHA (mantido anterior)${NC}"
        [ -f "$TEMP" ] && rm "$TEMP"
    fi
done

# 5. Reinicialização do Guardião (Aplica as novas regras de CPU/RAM)
echo -e "${AZUL}🔄 Reiniciando o Guardião (Nova versão)...${NC}"
# Mata a instância antiga que estava na memória
pkill -f autokil.sh || true

# Inicia a nova versão imediatamente em background (Daemon Mode)
if [ -f "$DIR_CONFIG/autokil.sh" ]; then
    nohup /bin/bash "$DIR_CONFIG/autokil.sh" > /dev/null 2>&1 &
    echo -e "${VERDE}✅ Guardião atualizado e rodando em tempo real!${NC}"
else
    echo -e "${VERMELHO}⚠️ Erro: autokil.sh não encontrado para inicialização.${NC}"
fi

# 6. Limpeza de Backups Antigos (Mais de 7 dias)
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo -e "${AZUL}---------------------------------------------------------------${NC}"
echo -e "${VERDE}✅ Sistema e scripts atualizados com sucesso!${NC}"
echo -e "${AMARELO}ℹ️ O Autokil já está operando com proteção de CPU + RAM.${NC}"
echo -e "${AZUL}===============================================================${NC}"

exit 0
