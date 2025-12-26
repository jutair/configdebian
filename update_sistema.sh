#!/bin/bash
# ===============================================================
# update_sistema.sh - Atualização Universal (Sudo-Friendly)
# ===============================================================

# --- CONFIGURAÇÕES ---
DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_BASE="https://raw.githubusercontent.com/jutair/configdebian/main"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# 1. VERIFICAÇÃO DE PRIVILÉGIO (Ajustada para aceitar sudo)
if [[ $EUID -ne 0 ]]; then
    echo -e "${VERMELHO}❌ Erro: Este script precisa de privilégios de root.${NC}"
    echo -e "${AMARELO}Dica: O menu deve chamá-lo com 'sudo -E bash'.${NC}"
    sleep 2
    exit 1
fi

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "                🔄 ATUALIZAÇÃO DO PAINEL"
echo -e "       Iniciada por: ${AMARELO}$(whoami)${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 2. LISTA DE SCRIPTS PARA SINCRONIZAR
SCRIPTS=(
    menu.sh
    open_vpn_conf.sh
    gerencia_rede.sh
    usuarios.sh
    setup_vps.sh
    backup.sh
    update_sistema.sh
    guardiao.sh
    login.sh
)

# 3. DOWNLOAD ATÔMICO
echo -e "${AMARELO}⏳ Baixando atualizações do GitHub...${NC}"

for script in "${SCRIPTS[@]}"; do
    URL="$GITHUB_BASE/$script"
    DEST="$DIR_CONFIG/$script"
    
    echo -ne " ${AZUL}→${NC} $script : "
    if curl -fsSL "$URL" -o "$DEST.tmp"; then
        mv "$DEST.tmp" "$DEST"
        chmod +x "$DEST"
        echo -e "${VERDE}OK!${NC}"
    else
        echo -e "${VERMELHO}FALHA${NC}"
        [ -f "$DEST.tmp" ] && rm -f "$DEST.tmp"
    fi
done

# 4. REAPLICAR TRAVAS DE SEGURANÇA
echo -e "${AMARELO}🛡️  Revisando permissões e travas do sistema...${NC}"

# Garante PAM (Alerta Login)
if ! grep -q "login.sh" /etc/pam.d/sshd; then
    echo "session optional pam_exec.so /opt/configdebian/login.sh" >> /etc/pam.d/sshd
fi

# Garante Jaula (Profile)
if ! grep -q "menu.sh" /etc/profile; then
    echo '[ -f /opt/configdebian/menu.sh ] && exec bash /opt/configdebian/menu.sh' >> /etc/profile
fi

# 5. REINICIAR GUARDIÃO (Via Systemd para garantir a atualização)
echo -e "${AMARELO}🔄 Reiniciando o serviço do Guardião...${NC}"

# Verifica se o serviço existe, se não, cria (garantia extra)
if [ ! -f "/etc/systemd/system/guardiao.service" ]; then
    printf "[Unit]\nDescription=Guardiao VPS ConfigDebian\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=/bin/bash %s/guardiao.sh\nRestart=always\nRestartSec=5\nUser=root\n\n[Install]\nWantedBy=multi-user.target\n" "$DIR_CONFIG" > /etc/systemd/system/guardiao.service
    systemctl daemon-reload
    systemctl enable guardiao.service
fi

# Comando mestre: Reinicia o serviço para ler o novo script baixado
systemctl restart guardiao.service

echo -e "${AZUL}---------------------------------------------------------------${NC}"
echo -e "${VERDE}✅ PAINEL E GUARDIÃO ATUALIZADOS COM SUCESSO!${NC}"
echo -e "${AZUL}===============================================================${NC}"
sleep 2
