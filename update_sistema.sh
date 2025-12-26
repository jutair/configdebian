#!/bin/bash
# update_sistema.sh - Atualização Blindada e Atômica (Versão 26/12/2025)

# --- CONFIGURAÇÕES DE IDENTIDADE E SEGURANÇA ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
BACKUP_DIR="/opt/configdebian/backups"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# 1. Carrega o Administrador Oficial para referência
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

# 2. Detecção AUID (Quem está rodando o script agora)
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_OPERADOR=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_OPERADOR=$(whoami)
fi

# --- 🛡️ TRAVA ANTI-TERMINAL ---
finalizar_sessao_update() {
    # Se não for o administrador, qualquer tentativa de interrupção mata a conexão
    if [ "$USER_OPERADOR" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ ATUALIZAÇÃO INTERROMPIDA! Desconectando por segurança...${NC}"
        pkill -u "$USER_OPERADOR" -9
        exit 1
    else
        echo -e "\n${AMARELO}Interrupção detectada pelo Administrador. Cancelando...${NC}"
        exit 1
    fi
}
# Bloqueia Ctrl+C, Ctrl+Z e saídas forçadas
trap finalizar_sessao_update SIGINT SIGTSTP SIGQUIT

# --- INÍCIO DA ATUALIZAÇÃO ---

if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute com sudo!${NC}"
  sleep 2; exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "                🔄 ATUALIZAÇÃO CENTRALIZADA"
echo -e "  Operador: ${AMARELO}$USER_OPERADOR${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 1. Sincronismo de Pacotes do Sistema
echo -e "${AMARELO}⌛ Sincronizando repositórios e dependências...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget vnstat ufw fail2ban bc

# 2. Backup de Segurança
DATA_BKP=$(date +"%Y%m%d-%H%M%S")
mkdir -p "$BACKUP_DIR/$DATA_BKP"
echo -e "${AZUL}📦 Criando backup preventivo em $BACKUP_DIR...${NC}"

SCRIPTS=(menu.sh open_vpn_conf.sh gerencia_rede.sh usuarios.sh configura_sistema.sh backup.sh update_sistema.sh autokil.sh)

for script in "${SCRIPTS[@]}"; do
    [ -f "$DIR_CONFIG/$script" ] && cp "$DIR_CONFIG/$script" "$BACKUP_DIR/$DATA_BKP/"
done

# 3. Download e Substituição Atômica (.tmp -> original)
GITHUB_BASE="https://raw.githubusercontent.com/jutair/configdebian/main"
echo -e "${AZUL}⏳ Baixando novas versões do GitHub...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"
    TEMP="$DEST.tmp"

    echo -ne "${AMARELO}→ $script : ${NC}"
    if curl -fsSL "$URL" -o "$TEMP"; then
        mv "$TEMP" "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}ATUALIZADO${NC}"
    else
        echo -e "${VERMELHO}FALHA (Mantido anterior)${NC}"
        rm -f "$TEMP"
    fi
done

# 4. Reinicialização do Guardião (Auto-Kill)
echo -e "${AZUL}🔄 Recarregando Guardião na Memória RAM...${NC}"
pkill -f autokil.sh || true
sleep 1

if [ -f "$DIR_CONFIG/autokil.sh" ]; then
    nohup /bin/bash "$DIR_CONFIG/autokil.sh" > /dev/null 2>&1 &
    echo -e "${VERDE}✅ Guardião reiniciado com sucesso!${NC}"
else
    echo -e "${VERMELHO}⚠️ Alerta: autokil.sh não encontrado!${NC}"
fi

# 5. Limpeza de Logs e Backups Antigos (Mais de 7 dias)
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo -e "${AZUL}---------------------------------------------------------------${NC}"
echo -e "${VERDE}✅ SISTEMA ATUALIZADO COM SUCESSO!${NC}"
echo -e "${AMARELO}Pressione ENTER para retornar ao menu...${NC}"
echo -e "${AZUL}===============================================================${NC}"

# Mantém o usuário preso até ele dar ENTER para voltar ao menu pai
read -r
exit 0
