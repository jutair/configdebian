#!/bin/bash

# ===============================================================
# 🛡️ VPS GUARDIÃO - MONITORAMENTO EM TEMPO REAL
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_CPU=70        # Mata processos acima de 50%
INTERVALO=10         # Verifica a cada 10 segundos
LOG_FILE="/var/log/vps_autokill.log"

# --- CORES PARA LOG NO TERMINAL ---
VERMELHO='\033[0;31m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
NC='\033[0m'

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

echo -e "${VERDE}🚀 Guardião Iniciado! Monitorando a cada $INTERVALO segundos...${NC}"

# --- LOOP INFINITO (DAEMON) ---
while true; do
    # Captura processos abusivos (exclui ROOT e processos de sistema)
    # Formato: usuario|pid|cpu|comando
    mapfile -t PROCESSOS < <(ps -aux --sort=-%cpu | awk -v lim="$LIMITE_CPU" '$3 > lim && $1 != "root" && $1 != "daemon" && $1 != "dbus" {print $1"|"$2"|"$3"|"$11}')

    for linha in "${PROCESSOS[@]}"; do
        USER_PROC=$(echo "$linha" | cut -d'|' -f1)
        PID_PROC=$(echo "$linha" | cut -d'|' -f2)
        CPU_PROC=$(echo "$linha" | cut -d'|' -f3)
        CMD_PROC=$(echo "$linha" | cut -d'|' -f4)

        # AÇÃO DE KILL
        kill -9 "$PID_PROC" 2>/dev/null

        # REGISTRO NO LOG
        DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
        echo "[$DATA_HORA] MATOU: $USER_PROC | PID: $PID_PROC | CPU: $CPU_PROC% | CMD: $CMD_PROC" >> "$LOG_FILE"

        # ALERTA TELEGRAM
        MENSAGEM="🚨 <b>ABUSO DE CPU DETECTADO</b>%0A👤 <b>Usuário:</b> <code>$USER_PROC</code>%0A🆔 <b>PID:</b> <code>$PID_PROC</code>%0A🔥 <b>Consumo:</b> <code>$CPU_PROC%</code>%0A⚙️ <b>Comando:</b> <code>$CMD_PROC</code>%0A🛡️ <i>O processo foi encerrado automaticamente.</i>"
        enviar_telegram "$MENSAGEM"
        
        echo -e "${VERMELHO}![X] Processo $PID_PROC ($USER_PROC) encerrado com $CPU_PROC% de CPU.${NC}"
    done

    sleep "$INTERVALO"
done
