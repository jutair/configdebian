#!/bin/bash
# autokil.sh - Versão Debug Total

LOG_FILE="/var/log/vps_autokill.log"
CONFIG_TELEGRAM="/etc/vps_protecao/telegram.conf"

# Garante que o arquivo de log exista e o root possa escrever
touch $LOG_FILE

# Carrega configurações do Telegram
[ -f "$CONFIG_TELEGRAM" ] && source "$CONFIG_TELEGRAM"

# Função para enviar Telegram
enviar_telegram() {
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$1" \
            -d parse_mode="HTML" > /dev/null
    fi
}

# Varre processos de usuários comuns (UID >= 1000)
# O ps h -eo extrai: pid, user, %cpu, uid
ps h -eo pid,user:%p,pcpu,uid | while read -r PID USER CPU UID_USER; do
    
    # Converte CPU para número inteiro para comparar
    CPU_INT=$(printf "%.0f" "$CPU")

    # REGRA: Se CPU > 80% e Usuário não for ROOT (UID >= 1000)
    if [ "$CPU_INT" -gt 80 ] && [ "$UID_USER" -ge 1000 ]; then
        
        # Tenta matar o processo
        kill -9 "$PID"
        
        # Registra no Log
        MSG="⚠️ $(date '+%Y-%m-%d %H:%M:%S') - USUÁRIO: $USER | PROCESSO: $PID | CPU: $CPU_INT%"
        echo "$MSG" >> "$LOG_FILE"
        
        # Envia Alerta
        enviar_telegram "<b>🚨 PROCESSO ENCERRADO</b>%0A<b>Usuário:</b> $USER%0A<b>CPU:</b> $CPU_INT%%0A<b>PID:</b> $PID"
    fi
done
