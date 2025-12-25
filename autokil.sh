#!/bin/bash

# ===============================================================
# 🛡️ GUARDIÃO VPS - PROTEÇÃO CPU + RAM (SOMA TOTAL)
# ===============================================================

# --- CONFIGURAÇÕES ---
LIMITE_CPU=60         # Se a SOMA da CPU do user passar de 60%
LIMITE_RAM=50         # Se a SOMA da RAM do user passar de 50%
INTERVALO=10          # Verificação a cada 10 segundos
LOG_FILE="/var/log/vps_autokill.log"
MEU_USUARIO="jutair"  # Usuário imune (seu login)

# --- CARREGA CONFIGURAÇÕES DO TELEGRAM ---
CONF_FILE="/etc/vps_protecao/telegram.conf"
if [ -f "$CONF_FILE" ]; then
    # Exporta as variáveis para que fiquem visíveis ao curl
    export $(grep -v '^#' "$CONF_FILE" | xargs)
fi

enviar_telegram() {
    local msg="$1"
    # Verifica se TOKEN e ID_CHAT foram carregados
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        /usr/bin/curl -s --connect-timeout 10 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
             -d "chat_id=${ID_CHAT}" \
             -d "text=${msg}" \
             -d "parse_mode=HTML" > /dev/null 2>&1
    fi
}

# --- LIMPEZA DE INSTÂNCIAS ANTERIORES (EVITA DUPLICADOS) ---
PID_ATUAL=$$
pgrep -f "autokil.sh" | grep -v $PID_ATUAL | xargs kill -9 > /dev/null 2>&1

echo "🚀 Guardião CPU ($LIMITE_CPU%) e RAM ($LIMITE_RAM%) iniciado com sucesso!"

while true; do
    # 🔍 LÓGICA DE SOMA POR USUÁRIO (Captura CPU e RAM juntas)
    # O awk processa o ps aux e gera uma saída formatada: usuario|motivo|dados
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
                # Formatamos a saída para o shell ler sem erro de espaços
                printf "%s|%s|CPU:%.1f%%_RAM:%.1f%%\n", u, motivo, cpu[u], ram[u]
            }
        }
    }')

    # Se a lista não estiver vazia, processa as expulsões
    if [ ! -z "$LISTA" ]; then
        echo "$LISTA" | while IFS='|' read -r USER_ALVO MOTIVO STATUS_TOTAL; do
            
            # 💀 PUNIÇÃO: Mata todos os processos do usuário abusivo
            pkill -u "$USER_ALVO" -9 2>/dev/null

            # 📝 REGISTRO NO LOG
            DATA_HORA=$(date +'%d/%m/%Y %H:%M:%S')
            echo "[$DATA_HORA] EXPULSO: $USER_ALVO | Motivo: $MOTIVO | $STATUS_TOTAL" >> "$LOG_FILE"

            # 📱 MONTAGEM DA MENSAGEM DO TELEGRAM
            NOME_VPS=$(hostname)
            # Pega IP local para evitar lentidão de rede externa
            IP_EXTERNO=$(hostname -I | awk '{print $1}')
            
            MENSAGEM="🚨 <b>ABUSO DETECTADO</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS ($IP_EXTERNO)</code>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A🔥 <b>Motivo:</b> <code>$MOTIVO</code>%0A📊 <b>Uso:</b> <code>$STATUS_TOTAL</code>"
            
            enviar_telegram "$MENSAGEM"
        done
    fi

    sleep "$INTERVALO"
done
