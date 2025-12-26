#!/bin/bash
# guardiao.sh - Proteção de Recursos e Ban Temporário
# Atualizado: 26-12-2025

# --- CONFIGURAÇÕES DE RECURSOS ---
LIMITE_CPU=60         # Limite de 60% de CPU
LIMITE_RAM=50         # Limite de 50% de RAM
TEMPO_BAN=300         # Ban de 5 minutos
INTERVALO=10          # Verificação a cada 10s
LOG_FILE="/var/log/vps_autokill.log"

# --- 🛡️ CARREGA IMUNIDADE DINÂMICA ---
# Lê os nomes definidos no configura_sistema.sh
CONF_VPS="/etc/vps_protecao/config.conf"
if [ -f "$CONF_VPS" ]; then
    source "$CONF_VPS"
else
    ADM_USER="root" # Fallback caso o arquivo não exista
    OPE_USER=""
fi

# --- CARREGA TELEGRAM ---
CONF_TELEGRAM="/etc/vps_protecao/telegram.conf"
if [ -f "$CONF_TELEGRAM" ]; then
    export $(grep -v '^#' "$CONF_TELEGRAM" | xargs)
fi

enviar_telegram() {
    local msg="$1"
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        /usr/bin/curl -s --connect-timeout 10 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
             -d "chat_id=${ID_CHAT}" \
             -d "text=${msg}" \
             -d "parse_mode=HTML" > /dev/null 2>&1
    fi
}

# --- LIMPEZA DE INSTÂNCIAS ANTIGAS ---
PID_ATUAL=$$
pgrep -f "guardiao.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1 || true

echo "🚀 Guardião Ativado!"
echo "Imunidade para: $ADM_USER e $OPE_USER"

while true; do
    # 🔍 DETECÇÃO DE ABUSO (Ignora Root, Daemon, Admin e Operador)
    LISTA=$(ps -aux | awk -v l_cpu="$LIMITE_CPU" -v l_ram="$LIMITE_RAM" -v adm="$ADM_USER" -v ope="$OPE_USER" '
    NR>1 && $1 != "root" && $1 != "daemon" && $1 != adm && $1 != ope && $11 !~ /guardiao/ {
        cpu[$1]+=$3
        ram[$1]+=$4
    } 
    END {
        for (u in cpu) {
            motivo=""
            if (cpu[u] > l_cpu) motivo="CPU"
            if (ram[u] > l_ram) motivo="RAM"
            if (cpu[u] > l_cpu && ram[u] > l_ram) motivo="CPU_RAM"
            if (motivo != "") {
                printf "%s|%s|CPU:%.1f%%_RAM:%.1f%%\n", u, motivo, cpu[u], ram[u]
            }
        }
    }')

    if [ ! -z "$LISTA" ]; then
        echo "$LISTA" | while IFS='|' read -r USER_ALVO MOTIVO STATUS_TOTAL; do
            
            # 💀 PUNIÇÃO 1: Expulsão imediata
            pkill -u "$USER_ALVO" -9 2>/dev/null
            
            # 🔒 PUNIÇÃO 2: Bloqueio de conta (Ban Temporário)
            passwd -l "$USER_ALVO" > /dev/null 2>&1
            (sleep "$TEMPO_BAN" && passwd -u "$USER_ALVO") > /dev/null 2>&1 &

            # 📝 REGISTRO NO LOG
            DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
            echo "[$DATA_HORA] BANIDO: $USER_ALVO | Motivo: $MOTIVO | $STATUS_TOTAL" >> "$LOG_FILE"

            # 📱 ALERTA TELEGRAM
            NOME_VPS=$(hostname)
            IP_EXTERNO=$(hostname -I | awk '{print $1}')
            MENSAGEM="🚫 <b>USUÁRIO BANIDO (5min)</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS ($IP_EXTERNO)</code>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Motivo:</b> <code>$MOTIVO</code>%0A📊 <b>Uso:</b> <code>$STATUS_TOTAL</code>"
            enviar_telegram "$MENSAGEM"
        done
    fi
    sleep "$INTERVALO"
done
