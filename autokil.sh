#!/bin/bash
# autokil.sh - Monitor com Alertas Remotos

LOG_FILE="/var/log/vps_autokill.log"
# Local onde o seu menu salvou o Token e o ID
CONFIG_TELEGRAM="/etc/vps_protecao/telegram.conf"

# Carrega as chaves silenciosamente
[ -f "$CONFIG_TELEGRAM" ] && source "$CONFIG_TELEGRAM"

enviar_telegram() {
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        local MENSAGEM="$1"
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$MENSAGEM" \
            -d parse_mode="HTML" > /dev/null
    fi
}

# --- EXEMPLO DE USO NO MONITOR DE CPU ---
# Quando o script matar um processo, ele chama:
# enviar_telegram "⚠️ <b>ALERTA:</b> Usuário $USER desconectado por CPU alta!"
