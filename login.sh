#!/bin/bash
# alerta_login.sh - Disparo instantâneo de login via Telegram

# --- CARREGA CONFIGURAÇÕES ---
CONF_TELEGRAM="/etc/vps_protecao/telegram.conf"
[ -f "$CONF_TELEGRAM" ] && export $(grep -v '^#' "$CONF_TELEGRAM" | xargs)

# Captura dados da sessão
USER_LOGIN=$PAM_USER
IP_LOGIN=$PAM_RHOST
DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
NOME_VPS=$(hostname)

# Ignora processos de sistema sem IP (logins locais/daemons)
if [ -z "$IP_LOGIN" ]; then exit 0; fi

# --- ENVIA PARA O TELEGRAM ---
MENSAGEM="🔐 <b>NOVA CONEXÃO DETECTADA</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS</code>%0A👤 <b>Usuário:</b> <code>$USER_LOGIN</code>%0A📍 <b>IP:</b> <code>$IP_LOGIN</code>%0A⏰ <b>Hora:</b> <code>$DATA_HORA</code>"

if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
    /usr/bin/curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
         -d "chat_id=${ID_CHAT}" \
         -d "text=${MENSAGEM}" \
         -d "parse_mode=HTML" > /dev/null 2>&1
fi
