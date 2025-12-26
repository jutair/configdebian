#!/bin/bash
# ===============================================================
# menu.sh - PAINEL MESTRE DE GESTÃO VPS (Versão Blindada 2025)
# ===============================================================
#!/bin/bash
# --- CORES ---
VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este script precisa de privilégios de ROOT.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

# --- RESTO DO CÓDIGO ---
echo "Agora eu tenho certeza que sou ROOT!"

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# 1. IDENTIFICAÇÃO DO ADMINISTRADOR E USUÁRIO LOGADO
# Carrega as variáveis ADM_USER e OPE_USER do arquivo de configuração
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

# Captura o usuário real que iniciou a sessão (mesmo sob sudo)
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_LOGADO=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_LOGADO=$(whoami)
fi

# 2. DEFINIÇÃO DINÂMICA DE RÓTULO DE PRIVILÉGIO
if [ "$USER_LOGADO" == "$ADM_USER" ]; then
    TIPO_USER="Administrador"
    COR_TIPO="${VERDE}"
else
    TIPO_USER="Operador"
    COR_TIPO="${AMARELO}"
fi

# --- 🛡️ FUNÇÃO DE ENCERRAMENTO (BLINDAGEM) ---
fechar_sistema() {
    clear
    if [[ "$USER_LOGADO" != "$ADM_USER" && "$USER_LOGADO" != "root" ]]; then
        echo -e "\n${VERMELHO}⚠️ SESSÃO ENCERRADA: Desconectando por segurança...${NC}"
        # Mata todos os processos do usuário operador para impedir que ele fique no shell
        pkill -u "$USER_LOGADO" -9
        exit 1
    else
        echo -e "\n${AMARELO}Saindo para o terminal de Administrador...${NC}"
        # Avisa o Telegram (via guardiao.sh) que o admin saiu para o shell
        exit 0
    fi
}

# Bloqueia interrupções de teclado (Ctrl+C, Ctrl+Z) para forçar o uso do menu
trap fechar_sistema SIGINT SIGTSTP SIGQUIT

# --- LOOP DO MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE CONTROLE VPS - MESTRE${NC}"
    echo -e "  Logado como: ${AMARELO}$USER_LOGADO${NC} | Privilégio: ${COR_TIPO}$TIPO_USER${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🔑 Gestão de Usuários (SSH/Samba)"
    echo -e "  [2] 🌐 Gerenciar OpenVPN (Status/Arquivos)"
    echo -e "  [3] ⚡
