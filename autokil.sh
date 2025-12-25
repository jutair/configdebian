#!/bin/bash
# autokil.sh - Versão Segura para GitHub

LOG_FILE="/var/log/vps_autokill.log"
CONFIG_TELEGRAM="/opt/configdebian/sec/telegram.conf"

# Tenta carregar as configurações do Telegram se o arquivo existir
if [ -f "$CONFIG_TELEGRAM" ]; then
    source "$CONFIG_TELEGRAM"
fi

enviar_telegram() {
    # Só tenta enviar se o TOKEN estiver configurado
    if [ ! -z "$TOKEN" ]; then
        local MENSAGEM="$1"
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$MENSAGEM" \
            -d parse_mode="HTML" > /dev/null
    fi
}

# --- Restante do código de monitoramento (CPU e DDoS) igual ao anterior ---
# Quando o script chamar enviar_telegram, ele usará as variáveis do arquivo local.
