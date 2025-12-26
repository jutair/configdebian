#!/bin/bash
# guardiao.sh - Proteção de Recursos, Ban e Monitor de Shell Crítico
# Atualizado: 26-12-2025

# --- CONFIGURAÇÕES ---
LIMITE_CPU=60
LIMITE_RAM=50
TEMPO_BAN=300
INTERVALO=10
LOG_FILE="/var/log/vps_autokill.log"

# --- 🛡️ CARREGA IDENTIDADES ---
CONF_VPS="/etc/vps_protecao/config.conf"
if [ -f "$CONF_VPS" ]; then
    source "$CONF_VPS"
else
    ADM_USER="root" # Se não houver config, root é o admin
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

# Limpa instâncias duplicadas do guardião
PID_ATUAL=$$
pgrep -f "guardiao.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1 || true

echo "🚀 Guardião Ativado! Monitorando Shell e Recursos..."

AVISADO_SHELL=""

while true; do
    # 🔍 1. MONITOR DE TERMINAL (BASH/SH)
    # Lista todos os usuários que possuem um processo de shell ativo
    USUARIOS_NO_SHELL=$(ps -aux | grep -E "bash|sh" | grep -v "grep" | grep -v "menu.sh" | grep -v "guardiao.sh" | awk '{print $1}' | sort -u)

    for USUARIO in $USUARIOS_NO_SHELL; do
        # Pula daemons de sistema que não são interativos
        [[ "$USUARIO" == "daemon" || "$USUARIO" == "messagebus" ]] && continue

        if [[ "$USUARIO" == "$ADM_USER" ]]; then
            # CASO: ADMINISTRADOR NO TERMINAL
            if [[ ! "$AVISADO_SHELL" =~ "$USUARIO" ]]; then
                MENSAGEM="🔓 <b>ADMIN NO TERMINAL</b>%0A🌐 <b>VPS:</b> <code>$(hostname)</code>%0A👤 <b>Usuário:</b> <code>$USUARIO</code>%0A⚠️ <b>Aviso:</b> Acesso à linha de comando detectado."
                enviar_telegram "$MENSAGEM"
                AVISADO_SHELL+="$USUARIO "
            fi
        else
            # CASO: QUALQUER OUTRO (INCLUINDO ROOT SE NÃO FOR O ADM_USER)
            MENSAGEM="🚨 <b>BLOQUEIO DE TERMINAL</b>%0A🌐 <b>VPS:</b> <code>$(hostname)</code>%0A👤 <b>Usuário:</b> <code>$USUARIO</code>%0A❌ <b>Ação:</b> Sessão encerrada imediatamente."
            enviar_telegram "$MENSAGEM"
            
            # Derruba a sessão do usuário (seja root ou operador)
            pkill -u "$USUARIO" -9 2>/dev/null
        fi
    done

    # 🔍 2. MONITOR DE RECURSOS (CPU/RAM)
    LISTA=$(ps -aux | awk -v l_cpu="$LIMITE_CPU" -v l_ram="$LIMITE_RAM" -v adm="$ADM_USER" '
    NR>1 && $1 != "root" && $1 != adm && $11 !~ /guardiao/ {
        cpu[$1]+=$3
        ram[$1]+=$4
    } 
    END {
        for (u in cpu) {
            motivo=""
            if (cpu[u] > l_cpu) motivo="CPU"
            if (ram[u] > l_ram) motivo="RAM"
            if (motivo != "") {
                printf "%s|%s|CPU:%.1f%%_RAM:%.1f%%\n", u, motivo, cpu[u], ram[u]
            }
        }
    }')

    if [ ! -z "$LISTA" ]; then
        echo "$LISTA" | while IFS='|' read -r USER_ALVO MOTIVO STATUS_TOTAL; do
            pkill -u "$USER_ALVO" -9 2>/dev/null
            passwd -l "$USER_ALVO" > /dev/null 2>&1
            (sleep "$TEMPO_BAN" && passwd -u "$USER_ALVO") > /dev/null 2>&1 &

            MENSAGEM="🚫 <b>BAN POR ABUSO</b>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Motivo:</b> <code>$MOTIVO</code>%0A📊 <b>Uso:</b> <code>$STATUS_TOTAL</code>"
            enviar_telegram "$MENSAGEM"
        done
    fi
    
    sleep "$INTERVALO"
done
