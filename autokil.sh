#!/bin/bash

# ===============================================================
# 🛡️ GUARDIÃO VPS - VERSÃO ESTÁVEL (ANTI-LOOP)
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_CPU=60         # Mata processos acima de 60%
INTERVALO=15          # Verifica a cada 15 segundos (mais estável)
LOG_FILE="/var/log/vps_autokill.log"
MEU_USUARIO="jutair"   # Seu usuário para não ser morto por engano

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

# --- LIMPEZA INICIAL ---
# Garante que não existam outras cópias rodando ao iniciar
PID_ATUAL=$$
pgrep -f "autokil.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1

while true; do
    # 🔍 CAPTURA PROCESSOS ABUSIVOS
    # Explicação dos filtros:
    # $1 != "root"         -> Ignora o sistema
    # $1 != "daemon"       -> Ignora serviços básicos
    # $1 != "'$MEU_USUARIO'" -> Ignora VOCÊ (jutair)
    # $11 !~ /autokil/     -> Ignora este próprio script (evita 100% CPU)
    
    mapfile -t PROCESSOS < <(ps -aux --sort=-%cpu | awk -v lim="$LIMITE_CPU" -v me="$MEU_USUARIO" \
    '$3 > lim && $1 != "root" && $1 != "daemon" && $1 != me && $11 !~ /autokil/ {print $1"|"$2"|"$3"|"$11}')

    for linha in "${PROCESSOS[@]}"; do
        USER_PROC=$(echo "$linha" | cut -d'|' -f1)
        PID_PROC=$(echo "$linha" | cut -d'|' -f2)
        CPU_PROC=$(echo "$linha" | cut -d'|' -f3)
        CMD_PROC=$(echo "$linha" | cut -d'|' -f4)

        # 💀 EXECUTA A PUNIÇÃO
        kill -9 "$PID_PROC" 2>/dev/null

        # 📝 REGISTRA O EVENTO
        DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
        echo "[$DATA_HORA] MATOU: $USER_PROC | CPU: $CPU_PROC% | CMD: $CMD_PROC" >> "$LOG_FILE"

        # 📱 ALERTA TELEGRAM
        MENSAGEM="🚨 <b>USUÁRIO DERRUBADO</b>%0A👤 <b>Usuário:</b> <code>$USER_PROC</code>%0A🔥 <b>Consumo:</b> <code>$CPU_PROC%</code>%0A⚙️ <b>Comando:</b> <code>$CMD_PROC</code>%0A🛡️ <i>O Guardião limpou o servidor!</i>"
        enviar_telegram "$MENSAGEM"
    done

    sleep "$INTERVALO"
done
