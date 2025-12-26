#!/bin/bash
# login.sh - Disparo instantâneo de login via Telegram
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

# --- CARREGA CONFIGURAÇÕES ---
CONF_TELEGRAM="/etc/vps_protecao/telegram.conf"

# Usa um método mais seguro para carregar as variáveis sem dar erro de export
if [ -f "$CONF_TELEGRAM" ]; then
    TOKEN=$(grep '^TOKEN=' "$CONF_TELEGRAM" | cut -d'"' -f2)
    ID_CHAT=$(grep '^ID_CHAT=' "$CONF_TELEGRAM" | cut -d'"' -f2)
fi

# Captura dados da sessão (Variáveis fornecidas pelo PAM)
USER_LOGIN=$PAM_USER
IP_LOGIN=$PAM_RHOST
DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
NOME_VPS=$(hostname)

# Ignora processos de sistema sem IP (logins locais/daemons internos)
if [ -z "$IP_LOGIN" ]; then exit 0; fi

# --- ENVIA PARA O TELEGRAM ---
MENSAGEM="🔐 <b>NOVA CONEXÃO DETECTADA</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS</code>%0A👤 <b>Usuário:</b> <code>$USER_LOGIN</code>%0A📍 <b>IP:</b> <code>$IP_LOGIN</code>%0A⏰ <b>Hora:</b> <code>$DATA_HORA</code>"

if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
    # Adicionado --connect-timeout para não travar o login se o Telegram estiver lento
    /usr/bin/curl -s --connect-timeout 5 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
         -d "chat_id=${ID_CHAT}" \
         -d "text=${MENSAGEM}" \
         -d "parse_mode=HTML" > /dev/null 2>&1
fi
