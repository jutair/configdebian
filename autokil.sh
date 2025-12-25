#!/bin/bash

# ===============================================================
# 🛡️ GUARDIÃO VPS - PROTEÇÃO CPU + RAM (SOMA TOTAL)
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_CPU=60         # Mata se a SOMA da CPU passar de 60%
LIMITE_RAM=50         # Mata se a SOMA da RAM passar de 50%
INTERVALO=10          # Verificação a cada 10 segundos
LOG_FILE="/var/log/vps_autokill.log"
MEU_USUARIO="jutair"  # Usuário imune

# --- CARREGA CONFIGURAÇÕES DO TELEGRAM ---
CONF_FILE="/etc/vps_protecao/telegram.conf"
if [ -f "$CONF_FILE" ]; then
    set -a
    source "$CONF_FILE"
    set +a
fi

enviar_telegram() {
    local msg="$1"
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        /usr/bin/curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
             -d "chat_id=${ID_CHAT}" \
             -d "text=${msg}" \
             -d "parse_mode=HTML" > /dev/null 2>&1
    fi
}

# --- LIMPEZA DE INSTÂNCIAS ANTERIORES ---
PID_ATUAL=$$
pgrep -f "autokil.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1

echo "🚀 Guardião CPU ($LIMITE_CPU%) e RAM ($LIMITE_RAM%) iniciado..."

while true; do
    # 🔍 LÓGICA DE SOMA POR USUÁRIO (CPU e RAM)
    # $3 é CPU, $4 é MEMÓRIA RAM
    mapfile -t USUARIOS_ABUSIVOS < <(ps -aux | awk -v l_cpu="$LIMITE_CPU" -v l_ram="$LIMITE_RAM" -v me="$MEU_USUARIO" '
    NR>1 && $1 != "root" && $1 != "daemon" && $1 != me && $11 !~ /autokil/ {
        cpu[$1]+=$3
        ram[$1]+=$4
    } 
    END {
        for (u in cpu) {
            motivo=""
            if (cpu[u] > l_cpu) motivo="CPU ("cpu[u]"%)"
            if (ram[u] > l_ram) motivo="RAM ("ram[u]"%)"
            if (cpu[u] > l_cpu && ram[u] > l_ram) motivo="CPU e RAM"
            
            if (motivo != "") print u"|"motivo"|CPU:"cpu[u]"% RAM:"ram[u]"%"
        }
    }')

    for linha in "${USUARIOS_ABUSIVOS[@]}"; do
        USER_ALVO=$(echo "$linha" | cut -d'|' -f1)
        MOTIVO=$(echo "$linha" | cut -d'|' -f2)
        STATUS_TOTAL=$(echo "$linha" | cut -d'|' -f3)

        # 💀 PUNIÇÃO
        pkill -u "$USER_ALVO" -9 2>/dev/null

        # 📝 REGISTRO NO LOG
        DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
        echo "[$DATA_HORA] EXPULSO: $USER_ALVO | Motivo: $MOTIVO | $STATUS_TOTAL" >> "$LOG_FILE"

        # 📱 ALERTA TELEGRAM
        NOME_VPS=$(hostname)
        IP_EXTERNO=$(curl -s https://api.ipify.org)
        MENSAGEM="🚨 <b>ABUSO DE RECURSOS</b>%0A🌐 <b>Servidor:</b> <code>$NOME_VPS</code>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Motivo:</b> <code>$MOTIVO</code>%0A📊 <b>Status:</b> <code>$STATUS_TOTAL</code>"
        enviar_telegram "$MENSAGEM"
    done

    sleep "$INTERVALO"
done
