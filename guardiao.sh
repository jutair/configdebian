#!/bin/bash

# ================= HARDENING =================
set -u
exec 9>/var/run/guardiao.lock
flock -n 9 || exit 0

renice +10 $$ >/dev/null 2>&1
ionice -c2 -n7 -p $$ >/dev/null 2>&1

# ================= CONFIG =================
DIR="/etc/vps_protecao"
TELEGRAM_CONF="$DIR/telegram.conf"
WHITELIST="$DIR/whitelist.conf"

[ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"

LOG="/var/log/guardiao.log"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

INTERFACE=$(ip route | awk '/default/ {print $5}')
LIMITE_GB=900

FLAG_BANDA="/tmp/alerta_banda"

# ================= LOG =================
log() {
    echo "$(date '+%F %T') | $1" >> "$LOG"
}

# ================= ALERTA =================
enviar_alerta() {
    local MSG="$1"
    local FLAG="${2:-}"

    [[ -z "${TOKEN:-}" || -z "${ID_CHAT:-}" ]] && return
    [[ -n "$FLAG" && -f "$FLAG" ]] && return

    timeout 5 curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$ID_CHAT" \
        -d text="$MSG" \
        -d parse_mode="HTML" >/dev/null

    [[ -n "$FLAG" ]] && touch "$FLAG"
    log "ALERTA: $MSG"
}

limpar_flag() {
    [[ -f "$1" ]] && rm -f "$1"
}

# ================= SERVIÇOS =================
check_servicos() {
    for S in openvpn sshd dnsmasq; do
        if ! systemctl is-active --quiet "$S"; then
            systemctl restart "$S"
            enviar_alerta "🔁 Serviço reiniciado: <b>$S</b>"
        fi
    done
}

# ================= SSH LOGIN =================
monitor_ssh_login() {
    local TMP="/tmp/ssh_now"
    local LAST="/tmp/ssh_last"

    tail -n 20 /var/log/auth.log 2>/dev/null | grep "Accepted" > "$TMP"

    [[ -f "$LAST" ]] && NOVOS=$(comm -13 "$LAST" "$TMP") || NOVOS=$(cat "$TMP")

    echo "$NOVOS" | while read -r linha; do
        IP=$(echo "$linha" | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}')
        USER=$(echo "$linha" | awk '{print $9}')
        [[ -z "$USER" ]] && continue

        enviar_alerta "🔐 <b>SSH LOGIN</b>%0A👤 $USER%0A🌐 $IP"
        log "SSH LOGIN: $USER $IP"
    done

    cp "$TMP" "$LAST"
}

# ================= VPN SESSÕES =================
monitor_vpn_sessoes() {

    local TMP="/tmp/vpn_now"
    local LAST="/tmp/vpn_last"

    awk -F',' '/^CLIENT_LIST/ {
        if ($2 != "Common Name")
            print $2 "|" $3 "|" $8
    }' "$STATUS_LOG" 2>/dev/null | sort > "$TMP"

    # primeira execução
    if [[ ! -f "$LAST" ]]; then
        cp "$TMP" "$LAST"
        return
    fi

    # LOGIN
    comm -13 "$LAST" "$TMP" | while IFS='|' read -r USER IP CONN_TIME; do
        [[ -z "$USER" ]] && continue

        enviar_alerta "🟢 <b>VPN LOGIN</b>%0A👤 $USER%0A🌐 $IP"
        log "VPN LOGIN: $USER $IP"
    done

    # LOGOUT
    comm -23 "$LAST" "$TMP" | while IFS='|' read -r USER IP CONN_TIME; do
        [[ -z "$USER" ]] && continue

        NOW=$(date +%s)
        TEMPO=$((NOW - CONN_TIME))
        (( TEMPO < 0 )) && TEMPO=0

        H=$((TEMPO / 3600))
        M=$(((TEMPO % 3600) / 60))

        enviar_alerta "🔴 <b>VPN LOGOUT</b>%0A👤 $USER%0A⏱ ${H}h ${M}m"
        log "VPN LOGOUT: $USER ${H}h${M}m"
    done

    controlar_multi_login "$TMP"

    cp "$TMP" "$LAST"
}

# ================= MULTI LOGIN =================
controlar_multi_login() {

    local TMP="$1"
    local LIMITE=1

    cut -d'|' -f1 "$TMP" | sort | uniq -c | while read -r COUNT USER; do

        (( COUNT <= LIMITE )) && continue

        enviar_alerta "⚠️ <b>MULTI LOGIN</b>%0A👤 $USER%0A🔢 $COUNT conexões"

        IPS=$(grep "^$USER|" "$TMP" | cut -d'|' -f2)

        i=0
        for IP in $IPS; do
            ((i++))

            # ignora rede interna VPN
            [[ "$IP" == 10.* ]] && continue

            if (( i > LIMITE )); then

                enviar_alerta "⛔ <b>SESSÃO ENCERRADA</b>%0A👤 $USER%0A🌐 $IP"

                pkill -f "$IP"

                log "DROP MULTI LOGIN: $USER $IP"

                FLAG="/tmp/multi_$USER"

                if [[ -f "$FLAG" ]]; then
                    banir_ip_auto "$IP"
                    enviar_alerta "🚫 <b>BLOQUEADO POR ABUSO</b>%0A👤 $USER%0A🌐 $IP"
                else
                    touch "$FLAG"
                fi

            fi
        done
    done
}

# ================= BANIMENTO =================
banir_ip_auto() {
    local IP="$1"

    grep -q "^$IP$" "$WHITELIST" 2>/dev/null && return

    bash /etc/vps_protecao/gerencia_rede.sh --ban "$IP"
    log "BAN AUTO: $IP"
}

# ================= ABUSO =================
detectar_abuso() {
    local NOW=$(date +%s)

    grep "^CLIENT_LIST," "$STATUS_LOG" 2>/dev/null | while IFS=',' read -r _ USER IP _ _ RX TX _; do

        [[ "$USER" == "Common Name" ]] && continue

        TOTAL=$((RX + TX))
        FILE="/tmp/abuse_$USER"

        if [[ -f "$FILE" ]]; then
            read LAST_TIME LAST_TOTAL < "$FILE"

            DT=$((NOW - LAST_TIME))
            DB=$((TOTAL - LAST_TOTAL))

            (( DT <= 0 )) && continue

            RATE=$((DB / DT / 1024 / 1024 * 60))

            if (( RATE > 300 )); then
                enviar_alerta "🚨 <b>ABUSO</b>%0A👤 $USER%0A🌐 $IP%0A📊 ${RATE}MB/min"
                banir_ip_auto "$IP"
            fi
        fi

        echo "$NOW $TOTAL" > "$FILE"
    done
}

# ================= CSV =================
gerar_consumo_por_usuario() {

    local PASTA="/var/log/vpn_consumo"
    local MES=$(date +'%m-%Y')

    mkdir -p "$PASTA"

    grep "^CLIENT_LIST," "$STATUS_LOG" 2>/dev/null | \
    while IFS=',' read -r _ USER _ _ _ RX TX _; do

        [[ "$USER" == "Common Name" ]] && continue

        ARQ="$PASTA/${USER}_${MES}.log"
        TMP="/tmp/last_${USER}"

        # valores atuais separados
        CUR_RX=$RX
        CUR_TX=$TX

        if [[ -f "$TMP" ]]; then
            read LAST_RX LAST_TX < "$TMP"
        else
            LAST_RX=0
            LAST_TX=0
        fi

        DIFF_RX=$((CUR_RX - LAST_RX))
        DIFF_TX=$((CUR_TX - LAST_TX))

        (( DIFF_RX < 0 )) && DIFF_RX=$CUR_RX
        (( DIFF_TX < 0 )) && DIFF_TX=$CUR_TX

        if [[ -f "$ARQ" ]]; then
            read OLD_RX OLD_TX < "$ARQ"
        else
            OLD_RX=0
            OLD_TX=0
        fi

        NEW_RX=$((OLD_RX + DIFF_RX))
        NEW_TX=$((OLD_TX + DIFF_TX))

        echo "$NEW_RX $NEW_TX" > "$ARQ"
        echo "$CUR_RX $CUR_TX" > "$TMP"

    done
}

# ================= BANDA =================
check_banda() {
    TOTAL=$(vnstat -i "$INTERFACE" --oneline 2>/dev/null | cut -d';' -f11)
    [[ -z "$TOTAL" ]] && return

    GB=$((TOTAL / 1024 / 1024))

    if (( GB >= LIMITE_GB )); then
        enviar_alerta "🚨 Consumo VPS: ${GB}GB" "$FLAG_BANDA"
    else
        limpar_flag "$FLAG_BANDA"
    fi
}

acumular_consumo_vpn() {

    local DB="/var/log/vpn_consumo_total.log"
    local TMP="/tmp/vpn_tmp_consumo"

    touch "$DB"

    grep "^CLIENT_LIST," "$STATUS_LOG" 2>/dev/null | \
    awk -F',' '{
        if($2!="Common Name"){
            print $2, $6, $7
        }
    }' > "$TMP"

    while read -r USER RX TX; do

        # valores atuais
        CUR_TOTAL=$((RX + TX))

        # arquivo de sessão
        FILE="/tmp/last_$USER"

        if [[ -f "$FILE" ]]; then
            LAST=$(cat "$FILE")
        else
            LAST=0
        fi

        DIFF=$((CUR_TOTAL - LAST))
        (( DIFF < 0 )) && DIFF=$CUR_TOTAL

        # atualizar DB
        if grep -q "^$USER " "$DB"; then
            OLD_RX=$(awk -v u="$USER" '$1==u{print $2}' "$DB")
            OLD_TX=$(awk -v u="$USER" '$1==u{print $3}' "$DB")

            NEW_TOTAL=$((OLD_RX + OLD_TX + DIFF))

            sed -i "s/^$USER .*/$USER $NEW_TOTAL 0/" "$DB"
        else
            echo "$USER $DIFF 0" >> "$DB"
        fi

        echo "$CUR_TOTAL" > "$FILE"

    done < "$TMP"
}

# ================= LOOP =================
tick=0

while true; do

    check_servicos

    (( tick % 2 == 0 )) && monitor_ssh_login
    (( tick % 2 == 0 )) && monitor_vpn_sessoes
    (( tick % 2 == 0 )) && acumular_consumo_vpn
    (( tick % 3 == 0 )) && detectar_abuso
    (( tick % 5 == 0 )) && gerar_consumo_por_usuario
    (( tick % 10 == 0 )) && check_banda

    sleep 60
    ((tick++))

done
