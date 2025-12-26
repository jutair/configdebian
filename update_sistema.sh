#!/bin/bash
# ===============================================================
# update_sistema.sh - Atualização Blindada e Atômica
# Versão: 26-12-2025
# ===============================================================

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
BACKUP_DIR="/opt/configdebian/backups"
DATA_ATUAL=$(date +"%Y%m%d-%H%M%S")
GITHUB_BASE="https://raw.githubusercontent.com/jutair/configdebian/main"

AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# --- 1. IDENTIFICAÇÃO E PROTEÇÃO ---
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_OPERADOR=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_OPERADOR=$(whoami)
fi

# Bloqueio de interrupção (Anti-Shell)
finalizar_sessao_update() {
    if [ "$USER_OPERADOR" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ ATUALIZAÇÃO INTERROMPIDA! Desconectando...${NC}"
        pkill -u "$USER_OPERADOR" -9
        exit 1
    else
        echo -e "\n${AMARELO}Cancelado pelo Administrador.${NC}"
        exit 1
    fi
}
trap finalizar_sessao_update SIGINT SIGTSTP SIGQUIT

# --- 2. VERIFICAÇÃO DE PRIVILÉGIO ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Erro: Execute como root/sudo.${NC}"
    sleep 2; exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "                🔄 ATUALIZAÇÃO DO SISTEMA"
echo -e "  Operador: ${AMARELO}$USER_OPERADOR${NC}"
echo -e "${AZUL}===============================================================${NC}"

# --- 3. ATUALIZAÇÃO DE PACOTES ---
echo -e "${AMARELO}⌛ Atualizando dependências e pacotes...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget vnstat ufw fail2ban bc procps

# --- 4. BACKUP PREVENTIVO ---
mkdir -p "$BACKUP_DIR/$DATA_ATUAL"
echo -e "${AZUL}📦 Criando backup da versão atual...${NC}"

SCRIPTS=(
    menu.sh
    open_vpn_conf.sh
    gerencia_rede.sh
    usuarios.sh
    configura_sistema.sh
    backup.sh
    update_sistema.sh
    guardiao.sh
    login.sh
)

for script in "${SCRIPTS[@]}"; do
    [ -f "$DIR_CONFIG/$script" ] && cp "$DIR_CONFIG/$script" "$BACKUP_DIR/$DATA_ATUAL/"
done

# --- 5. DOWNLOAD ATÔMICO (GITHUB) ---
echo -e "${AZUL}⏳ Sincronizando scripts com o repositório...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"
    TEMP="$DEST.tmp"

    echo -ne "${AMARELO}→ $script : ${NC}"
    if curl -fsSL "$URL" -o "$TEMP"; then
        mv "$TEMP" "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}OK!${NC}"
    else
        echo -e "${VERMELHO}FALHA (Mantido anterior)${NC}"
        [ -f "$TEMP" ] && rm -f "$TEMP"
    fi
done

# --- 6. APLICANDO REGRAS DE SEGURANÇA (PAM & SHELL) ---
echo -e "${AZUL}🛡️  Configurando travas de login e shell...${NC}"

# Garante a regra do login.sh no PAM
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so /opt/configdebian/login.sh" >> /etc/pam.d/sshd

# Garante a jaula do menu no Profile
sed -i '/menu.sh/d' /etc/profile
echo '[ -f /opt/configdebian/menu.sh ] && exec bash /opt/configdebian/menu.sh' >> /etc/profile

# --- 7. REINICIALIZAÇÃO DO GUARDIÃO ---
echo -e "${AZUL}🔄 Reiniciando Guardião (Monitor de Shell)...${NC}"
pkill -f guardiao.sh || true
sleep 1
if [ -f "$DIR_CONFIG/guardiao.sh" ]; then
    nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &
    echo -e "${VERDE}✅ Guardião atualizado e operando!${NC}"
else
    echo -e "${VERMELHO}⚠️ Erro: guardiao.sh não encontrado.${NC}"
fi

# Limpeza de backups com mais de 7 dias
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo -e "${AZUL}---------------------------------------------------------------${NC}"
echo -e "${VERDE}✅ ATUALIZAÇÃO COMPLETA! Todas as proteções estão ativas.${NC}"
echo -e "${AMARELO}Pressione ENTER para voltar ao menu...${NC}"
echo -e "${AZUL}===============================================================${NC}"

read -r
exit 0
