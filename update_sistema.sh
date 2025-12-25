#!/bin/bash
# update_sistema.sh - Atualização segura e atômica
# Versão: 25-12-2025

set -e

# --- CONFIGURAÇÕES ---
DIR_CONFIG="/opt/configdebian"
BACKUP_DIR="/opt/configdebian/backups"
DATA=$(date +"%Y%m%d-%H%M%S")
GITHUB_BASE="https://raw.githubusercontent.com/jutair/configdebian/main"

# Lista de scripts para atualizar
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
echo -e "                   🔄 ATUALIZAÇÃO DO SISTEMA"
echo -e "${AZUL}===============================================================${NC}"

# 2. Atualização de Repositórios e Pacotes do Sistema
echo -e "${AMARELO}⌛ Atualizando dependências do sistema...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y openvpn samba speedtest-cli bc sudo curl wget unzip vnstat ufw fail2ban

# 3. Backup de Segurança (Antes de sobrescrever)
mkdir -p "$BACKUP_DIR/$DATA"
echo -e "${AZUL}📦 Criando backup da versão atual...${NC}"
for script in "${SCRIPTS[@]}"; do
    [ -f "$DIR_CONFIG/$script" ] && cp "$DIR_CONFIG/$script" "$BACKUP_DIR/$DATA/"
done

# 4. Download Atômico e Substituição
echo -e "${AZUL}⏳ Sincronizando scripts com GitHub...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"
    TEMP="$DEST.tmp"

    echo -ne "${AMARELO}→ Atualizando $script ... ${NC}"

    # Tenta baixar para o arquivo temporário (.tmp)
    if curl -fsSL "$URL" -o "$TEMP"; then
        # Se baixou ok, move substituindo o original
        mv "$TEMP" "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}OK!${NC}"
    else
        echo -e "${VERMELHO}FALHA (mantido anterior)${NC}"
        [ -f "$TEMP" ] && rm -f "$TEMP"
    fi
done

# 5. REINICIALIZAÇÃO DO GUARDIÃO (MUITO IMPORTANTE)
# Isso mata a versão velha na RAM e sobe a nova com as melhorias
echo -e "${AZUL}🔄 Aplicando melhorias: Reiniciando Guardião (Auto-Kill)...${NC}"

# Mata instâncias antigas
pkill -f autokil.sh || true
sleep 1

# Inicia o novo autokil.sh em segundo plano (Daemon Mode)
if [ -f "$DIR_CONFIG/autokil.sh" ]; then
    # O nohup garante que o script não morra quando você sair do terminal
    nohup /bin/bash "$DIR_CONFIG/autokil.sh" > /dev/null 2>&1 &
    echo -e "${VERDE}✅ Guardião atualizado e operando com CPU + RAM!${NC}"
else
    echo -e "${VERMELHO}⚠️ Erro: Script autokil.sh não encontrado para iniciar.${NC}"
fi

# 6. Limpeza de Backups Antigos (Mantém apenas os últimos 7 dias)
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo -e "${AZUL}---------------------------------------------------------------${NC}"
echo -e "${VERDE}✅ ATUALIZAÇÃO COMPLETA COM SUCESSO!${NC}"
echo -e "${AMARELO}ℹ️ Todas as novas proteções já estão em vigor.${NC}"
echo -e "${AZUL}===============================================================${NC}"

exit 0
