#!/bin/bash

# ===============================================================
# 🛡️ GUARDIÃO VPS - PROTEÇÃO TOTAL COM BAN TEMPORÁRIO
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_CPU=60         # Limite de 60% de CPU
LIMITE_RAM=50         # Limite de 50% de RAM
TEMPO_BAN=300         # Tempo de bloqueio em segundos (300s = 5 min)
INTERVALO=10          # Verificação a cada 10 segundos
LOG_FILE="/var/log/vps_autokill.log"
MEU_USUARIO="jutair"  # Usuário imune

# --- CARREGA CONFIGURAÇÕES DO TELEGRAM ---
CONF_FILE="/etc/vps_protecao/telegram.conf"
if [ -f "$CONF_FILE" ]; then
    export $(grep -v '^#' "$CONF_FILE" | xargs)
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

# --- LIMPEZA DE INSTÂNCIAS ---
PID_ATUAL=$$
pgrep -f "autokil.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1

echo "🚀 Guardião Ativado: CPU ($LIMITE_CPU%), RAM ($LIMITE_RAM%) e Ban de 5min!"

while true; do
    # 🔍 DETECÇÃO DE ABUSO
    LISTA=$(ps -aux | awk -v l_cpu="$LIMITE_CPU" -v l_ram="$LIMITE_RAM" -v me="$MEU_USUARIO" '
    NR>1 && $1 != "root" && $1 != "daemon" && $1 != me && $11 !~ /autokil/ {
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
            
            # 💀 PUNIÇÃO 1: Expulsão imediata (Kill total)
            pkill -u "$USER_ALVO" -9 2>/dev/null
            
            # 🔒 PUNIÇÃO 2: Bloqueio de conta (Ban Temporário)
            # Bloqueia a senha e agenda o desbloqueio
            passwd -l "$USER_ALVO" > /dev/null 2>&1
            (sleep "$TEMPO_BAN" && passwd -u "$USER_ALVO") > /dev/null 2>&1 &

            # 📝 REGISTRO NO LOG
            DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
            echo "[$DATA_HORA] BANIDO (5min): $USER_ALVO | Motivo: $MOTIVO | $STATUS_TOTAL" >> "$LOG_FILE"

            # 📱 ALERTA TELEGRAM
            NOME_VPS=$(hostname)
            IP_EXTERNO=$(hostname -I | awk '{print $1}')
            
            MENSAGEM="🚫 <b>USUÁRIO BANIDO (5min)</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS ($IP_EXTERNO)</code>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Motivo:</b> <code>$MOTIVO</code>%0A📊 <b>Uso:</b> <code>$STATUS_TOTAL</code>"
            
            enviar_telegram "$MENSAGEM"
        done
    fi

    sleep "$INTERVALO"
done
