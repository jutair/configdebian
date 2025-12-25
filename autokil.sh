#!/bin/bash

# ===============================================================
# 🛡️ GUARDIÃO VPS - PROTEÇÃO CONTRA ABUSO TOTAL POR USUÁRIO
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_TOTAL=60        # Se a SOMA dos processos do user passar de 60%
INTERVALO=10           # Verificação a cada 10 segundos
LOG_FILE="/var/log/vps_autokill.log"
MEU_USUARIO="jutair"   # Seu usuário para nunca ser expulso

# --- CARREGA CONFIGURAÇÕES DO TELEGRAM ---
[ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf

enviar_telegram() {
    local msg="$1"
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
             -d chat_id="$ID_CHAT" \
             -d text="$msg" \
             -d parse_mode="HTML" > /dev/null
    fi
}

# --- LIMPEZA DE INSTÂNCIAS ANTERIORES ---
PID_ATUAL=$$
pgrep -f "autokil.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1

echo "🚀 Monitor de CPU Total iniciado (Limite: $LIMITE_TOTAL%)..."

while true; do
    # 🔍 LÓGICA DE SOMA POR USUÁRIO
    # O awk soma a coluna 3 ($3 - CPU) agrupando pela coluna 1 ($1 - Usuário)
    # Filtros: Ignora root, daemon, seu usuário e o próprio script
    
    mapfile -t USUARIOS_ABUSIVOS < <(ps -aux | awk -v lim="$LIMITE_TOTAL" -v me="$MEU_USUARIO" '
    NR>1 && $1 != "root" && $1 != "daemon" && $1 != me && $11 !~ /autokil/ {
        cpu[$1]+=$3
    } 
    END {
        for (u in cpu) {
            if (cpu[u] > lim) print u"|"cpu[u]
        }
    }')

    for linha in "${USUARIOS_ABUSIVOS[@]}"; do
        USER_ALVO=$(echo "$linha" | cut -d'|' -f1)
        SOMA_CPU=$(echo "$linha" | cut -d'|' -f2)

        # 💀 PUNIÇÃO: Mata TODOS os processos do usuário de uma vez
        # Isso resolve o problema de vários processos "cat" e "md5sum"
        pkill -u "$USER_ALVO" -9 2>/dev/null

        # 📝 REGISTRO NO LOG
        DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
        echo "[$DATA_HORA] EXPULSO: $USER_ALVO | CPU TOTAL: $SOMA_CPU%" >> "$LOG_FILE"

        # 📱 ALERTA TELEGRAM
        MENSAGEM="⚠️ <b>USUÁRIO EXPULSO POR ABUSO</b>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Consumo Total:</b> <code>$SOMA_CPU%</code>%0A🛡️ <i>A VPS estava em 100% e o Guardião removeu o invasor.</i>"
        enviar_telegram "$MENSAGEM"
    done

    sleep "$INTERVALO"
done
