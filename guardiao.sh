#!/bin/bash
# =========================================================
# GUARDIÃO - Monitoramento 24/7 de VPN, DNS, Banda e Recursos
# =========================================================

# ---------------- CONFIGURAÇÕES ----------------
DIR_PROT="/etc/vps_protecao"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
CONFIG_CONF="$DIR_PROT/config.conf"
PASTA_CONSUMO="$DIR_PROT/consumo_clientes"

ARQUIVO_ALERTA_BANDA="/tmp/alerta_banda_enviado"
ARQUIVO_ALERTA_RECURSOS="/tmp/alerta_recursos_enviado"
ARQUIVO_ALERTA_DNS="/tmp/alerta_dns_enviado"

LIMITE_GB=900
LIMITE_CPU=95
LIMITE_RAM=85

DNS_CONF="/etc/dnsmasq.d/vpn.conf"
DNS_LOCK="/var/run/vpn_dns_ativado.lock"

PASTA_CONSUMO="/var/log/vpn_consumo"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

# ---------------- CARREGA CONFIGS ----------------
[ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"
[ -f "$CONFIG_CONF" ] && source "$CONFIG_CONF"

INTERFACE_PRIN=$(ip route | awk '/default/ {print $5}')

# =================================================
# FUNÇÃO: ALERTA TELEGRAM
# =================================================
enviar_alerta() {
    local MSG="$1"
    [[ -z "$TOKEN" || -z "$ID_CHAT" ]] && return
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$ID_CHAT" \
        -d text="$MSG" \
        -d parse_mode="HTML" >/dev/null
}

# =================================================
# FUNÇÃO: VERIFICA SE DNS DA VPN ESTÁ OK
# =================================================
verificar_dns_vpn() {
    local INT_VPN
    INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)

    [[ -z "$INT_VPN" ]] && return 1
    [[ ! -f "$DNS_LOCK" ]] && return 1
    [[ ! -f "$DNS_CONF" ]] && return 1

    grep -q "^interface=$INT_VPN" "$DNS_CONF"
}

# =================================================
# FUNÇÃO: ATIVA DNS DA VPN (1x, SEM INTERFERIR)
# =================================================
ativa_dns() {
    # Já ativado
    [ -f "$DNS_LOCK" ] && return 0

    # VPN ainda não existe
    local INT_VPN
    INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
    [[ -z "$INT_VPN" ]] && return 0

    # Função externa (menu/admin)
    if command -v configurar_dnsmasq_vpn &>/dev/null; then
        configurar_dnsmasq_vpn ativar >/dev/null 2>&1
        logger "[GUARDIAO] Tentativa automática de ativação do DNS da VPN"
    fi
}

# =================================================
# FUNÇÃO: MONITORAMENTO VPN + DNS
# =================================================
monitor_vpn() {
    if verificar_dns_vpn; then
        [ -f "$ARQUIVO_ALERTA_DNS" ] && rm -f "$ARQUIVO_ALERTA_DNS"
        logger "[GUARDIAO] VPN e DNS OK"
    else
        if [ ! -f "$ARQUIVO_ALERTA_DNS" ]; then
            enviar_alerta "❌ <b>DNS da VPN NÃO está configurado corretamente</b>"
            touch "$ARQUIVO_ALERTA_DNS"
        fi
    fi
}

# =================================================
# FUNÇÃO: RASTREAR CONSUMO POR CLIENTE VPN
# =================================================
rastrear_clientes_vpn() {
    local MES_ATUAL=$(date +'%m-%Y')
    [ ! -f "$STATUS_LOG" ] && return
    [ ! -d "$PASTA_CONSUMO" ] && mkdir -p "$PASTA_CONSUMO"

    # Processa o Formato 2 (CLIENT_LIST)
    grep "^CLIENT_LIST," "$STATUS_LOG" | while IFS=',' read -r TIPO NOME IP_REAL IP_VIRT IP_V6 BYTES_RECV BYTES_SENT RESTO; do
        [[ -z "$NOME" || "$NOME" == "Common Name" ]] && continue

        ARQ_HIST="$PASTA_CONSUMO/${NOME}_${MES_ATUAL}.log"
        ARQ_SESS="/tmp/${NOME}_last_session.tmp"

        RECV=${BYTES_RECV:-0}
        SENT=${BYTES_SENT:-0}

        [ ! -f "$ARQ_HIST" ] && echo "0 0" > "$ARQ_HIST"
        [ ! -f "$ARQ_SESS" ] && echo "0 0" > "$ARQ_SESS"

        read -r ACC_RECV ACC_SENT < "$ARQ_HIST"
        read -r LAST_RECV LAST_SENT < "$ARQ_SESS"

        if (( RECV < LAST_RECV )); then
            DIFF_RECV=$RECV
            DIFF_SENT=$SENT
        else
            DIFF_RECV=$((RECV - LAST_RECV))
            DIFF_SENT=$((SENT - LAST_SENT))
        fi

        echo "$((ACC_RECV + DIFF_RECV)) $((ACC_SENT + DIFF_SENT))" > "$ARQ_HIST"
        echo "$RECV $SENT" > "$ARQ_SESS"
    done
}

# --- FUNÇÃO 2: GERAR CSV EM MB ---
gerar_relatorio_csv() {
    local MES_ATUAL=$(date +'%m-%Y')
    local ARQUIVO_CSV="$PASTA_CONSUMO/relatorio_consumo_${MES_ATUAL}.csv"
    
    # Cabeçalho
    echo "Usuario,Recebido_MB,Enviado_MB,Data_Relatorio" > "$ARQUIVO_CSV"

    for arq in "$PASTA_CONSUMO"/*_"${MES_ATUAL}".log; do
        [ ! -f "$arq" ] && continue
        USUARIO=$(basename "$arq" | sed "s/_${MES_ATUAL}.log//")
        read -r BYTES_RECV BYTES_SENT < "$arq"

        # Cálculo em MB via awk (mais rápido que bc para loops)
        MB_RECV=$(awk "BEGIN {printf \"%.2f\", $BYTES_RECV/1048576}")
        MB_SENT=$(awk "BEGIN {printf \"%.2f\", $BYTES_SENT/1048576}")

        echo "${USUARIO},${MB_RECV},${MB_SENT},$(date +%Y-%m-%d)" >> "$ARQUIVO_CSV"
    done
}
# =================================================
# FUNÇÃO: COTA GLOBAL DA VPS
# =================================================
verificar_cota_vps() {
    command -v vnstat &>/dev/null || return
    command -v jq &>/dev/null || return

    DATA_JSON=$(vnstat --json m 2>/dev/null)
    RX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].rx")
    TX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].tx")

    TOTAL_GB=$(echo "scale=2; ($RX+$TX)/1024/1024/1024" | bc -l)

    if (( $(echo "$TOTAL_GB >= $LIMITE_GB" | bc -l) )); then
        if [ ! -f "$ARQUIVO_ALERTA_BANDA" ]; then
            enviar_alerta "🚨 <b>ALERTA DE CONSUMO VPS</b>%0A📊 <code>$TOTAL_GB GB</code>"
            touch "$ARQUIVO_ALERTA_BANDA"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_BANDA" ] && rm -f "$ARQUIVO_ALERTA_BANDA"
    fi
}

# =================================================
# FUNÇÃO: MONITORAR CPU E RAM
# =================================================
verificar_recursos_sistema() {
    USO_CPU=$(top -bn1 | awk '/Cpu/ {print 100-$8}' | cut -d. -f1)
    USO_RAM=$(free | awk '/Mem/ {printf "%.0f", $3/$2*100}')

    if (( USO_CPU > LIMITE_CPU || USO_RAM > LIMITE_RAM )); then
        if [ ! -f "$ARQUIVO_ALERTA_RECURSOS" ]; then
            enviar_alerta "⚠️ <b>SOBREUSO VPS</b>%0ACPU: $USO_CPU% | RAM: $USO_RAM%"
            touch "$ARQUIVO_ALERTA_RECURSOS"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_RECURSOS" ] && rm -f "$ARQUIVO_ALERTA_RECURSOS"
    fi
}

# =================================================
# FUNÇÃO: SERVIÇOS ESSENCIAIS
# =================================================
verificar_servicos() {
    for SERV in openvpn sshd vnstat dnsmasq; do
        systemctl is-active --quiet "$SERV" || systemctl restart "$SERV"
    done
}

# =================================================
# LOOP PRINCIPAL DO GUARDIÃO
# =================================================
while true; do
    #verificar_recursos_sistema
    verificar_servicos
    rastrear_clientes_vpn
    gerar_relatorio_csv
    verificar_cota_vps

    ativa_dns
    monitor_vpn

    sleep 50
done
