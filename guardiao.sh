#!/bin/bash
# guardiao.sh - Monitoramento 24/7 de Serviços e Consumo de Banda

# --- CONFIGURAÇÕES DE CAMINHOS ---
DIR_PROT="/etc/vps_protecao"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
CONFIG_CONF="$DIR_PROT/config.conf"
PASTA_CONSUMO="$DIR_PROT/consumo_clientes"  # Pasta criada no setup_vps.sh

ARQUIVO_ALERTA_BANDA="/tmp/alerta_banda_enviado"
ARQUIVO_ALERTA_RECURSOS="/tmp/alerta_recursos_enviado"
LIMITE_GB=900
LIMITE_CPU=85
LIMITE_RAM=85

# Carrega configurações e credenciais
[ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"
[ -f "$CONFIG_CONF" ] && source "$CONFIG_CONF"

# Detecta a interface principal automaticamente
INTERFACE_PRIN=$(ip route | grep default | awk '{print $5}')

# --- FUNÇÃO: ALERTA TELEGRAM ---
enviar_alerta() {
    local MSG=$1
    if [[ -n "$TOKEN" && -n "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$MSG" \
            -d parse_mode="HTML" > /dev/null
    fi
}

# --- FUNÇÃO: ATIVAR DNS DA VPN ---
ativa_dns() {
    local LOCK="/var/run/vpn_dns_ativado.lock"
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"

    # Executa apenas uma vez
    [ -f "$LOCK" ] && return 0

    # Verifica se alguma interface TUN está ativa
    INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
    if [[ -n "$INT_VPN" ]]; then
        IP_INT=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        IP_INT=${IP_INT:-"10.8.0.1"}

        # Evita duplicação
        if [[ -f "$DNS_CONF" ]] && ! grep -q "^interface=$INT_VPN" "$DNS_CONF"; then
            sed -i '/^interface=/d;/^bind-interfaces/d;/^listen-address=/d' "$DNS_CONF"
            echo -e "interface=$INT_VPN\nbind-interfaces\nlisten-address=$IP_INT" | sudo tee -a "$DNS_CONF" >/dev/null
            systemctl restart dnsmasq
            logger "[GUARDIAO] DNS da VPN ativado na interface $INT_VPN ($IP_INT)"
        fi

        # Cria lock
        touch "$LOCK"
        chmod 600 "$LOCK"
    fi
}

# --- FUNÇÃO: MONITORAMENTO VPN E DNS ---
monitor_vpn() {
    ativa_dns

    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
    local DNS_CONFIGURADO=0
    local ALERTA_LOCK="/tmp/alerta_dns_enviado"

    if [[ -n "$INT_VPN" && -f /etc/dnsmasq.d/vpn.conf ]]; then
        if grep -q "^interface=$INT_VPN" /etc/dnsmasq.d/vpn.conf; then
            DNS_CONFIGURADO=1
        fi
    fi

    if [[ $DNS_CONFIGURADO -eq 0 ]]; then
        if [ ! -f "$ALERTA_LOCK" ]; then
            enviar_alerta "❌ DNS da VPN não configurado para $INT_VPN!"
            touch "$ALERTA_LOCK"
        fi
    else
        [ -f "$ALERTA_LOCK" ] && rm -f "$ALERTA_LOCK"
        logger "[GUARDIAO] DNS da VPN configurado corretamente para $INT_VPN"
    fi
}

# --- FUNÇÃO: RASTREAR CONSUMO POR CLIENTE VPN ---
rastrear_clientes_vpn() {
    STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
    MES_ATUAL=$(date +'%m-%Y')
    PASTA_LOGS="$PASTA_CONSUMO"

    [ ! -f "$STATUS_LOG" ] && return

    grep "^CLIENT_LIST," "$STATUS_LOG" | while IFS=',' read -r \
        TIPO NOME IP_REAL IP_VPN CAMPO_VAZIO BYTES_RECV BYTES_SENT DATA_CONEXAO TIMESTAMP RESTO; do
        [[ -z "$NOME" || "$NOME" == "Common Name" ]] && continue

        ARQ_HIST="$PASTA_LOGS/${NOME}_${MES_ATUAL}.log"
        ARQ_SESS="/tmp/${NOME}_last_session.tmp"

        RECV=${BYTES_RECV:-0}
        SENT=${BYTES_SENT:-0}

        [ ! -f "$ARQ_HIST" ] && echo "0 0" > "$ARQ_HIST"
        [ ! -f "$ARQ_SESS" ] && echo "0 0" > "$ARQ_SESS"

        read -r ACC_RECV ACC_SENT < "$ARQ_HIST"
        read -r LAST_RECV LAST_SENT < "$ARQ_SESS"

        if [ "$RECV" -lt "$LAST_RECV" ]; then
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

# --- FUNÇÃO: MONITORAR COTA GLOBAL ---
verificar_cota_vps() {
    command -v jq &>/dev/null || return
    command -v vnstat &>/dev/null || return

    DATA_JSON=$(vnstat --json m 2>/dev/null)
    RX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].rx" 2>/dev/null || echo 0)
    TX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].tx" 2>/dev/null || echo 0)

    TOTAL_GB=$(echo "scale=2; ($RX + $TX) / 1024 / 1024 / 1024" | bc -l)

    if (( $(echo "$TOTAL_GB >= $LIMITE_GB" | bc -l) )); then
        if [ ! -f "$ARQUIVO_ALERTA_BANDA" ]; then
            MENSAGEM="🚨 <b>ALERTA DE CONSUMO VPS</b>%0A🌐 Interface: <code>$INTERFACE_PRIN</code>%0A📊 Consumo: <code>$TOTAL_GB GB</code>%0A⚠️ O limite de <b>900GB</b> foi atingido!"
            enviar_alerta "$MENSAGEM"
            touch "$ARQUIVO_ALERTA_BANDA"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_BANDA" ] && rm -f "$ARQUIVO_ALERTA_BANDA"
    fi
}

# --- FUNÇÃO: MONITORAR CPU E RAM ---
verificar_recursos_sistema() {
    USO_CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    USO_RAM=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)

    if [ "$USO_CPU" -gt "$LIMITE_CPU" ] || [ "$USO_RAM" -gt "$LIMITE_RAM" ]; then
        VILAO_NOME=$(ps -eo comm,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n1 | awk '{print $1}')
        VILAO_PID=$(ps -eo pid,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n1 | awk '{print $1}')
        VILAO_CPU=$(ps -eo %cpu --sort=-%cpu | head -n2 | tail -n1)
        VILAO_RAM=$(ps -eo %mem --sort=-%mem | head -n2 | tail -n1)

        if [[ "$VILAO_NOME" != "sshd" && "$VILAO_NOME" != "bash" && "$VILAO_NOME" != "guardiao.sh" ]]; then
            kill -9 "$VILAO_PID"
            STATUS_ACAO="O processo <b>$VILAO_NOME (PID: $VILAO_PID)</b> foi encerrado para proteger o sistema."
        else
            STATUS_ACAO="O processo vilão é vital ($VILAO_NOME) e não foi encerrado."
        fi

        if [ ! -f "$ARQUIVO_ALERTA_RECURSOS" ]; then
            MENSAGEM="⚠️ <b>ALERTA: SOBREUSO DE RECURSOS</b>%0A📊 CPU: <code>$USO_CPU%</code> | RAM: <code>$USO_RAM%</code>%0A🔥 Culpado: <code>$VILAO_NOME</code>%0A📉 Uso do Culpado: CPU $VILAO_CPU% | RAM $VILAO_RAM%%0A🛡️ <b>Ação:</b> $STATUS_ACAO"
            enviar_alerta "$MENSAGEM"
            touch "$ARQUIVO_ALERTA_RECURSOS"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_RECURSOS" ] && rm -f "$ARQUIVO_ALERTA_RECURSOS"
    fi
}

# --- FUNÇÃO: VERIFICAÇÃO DE SERVIÇOS ESSENCIAIS ---
verificar_servicos() {
    local SERVICOS=("openvpn" "sshd" "vnstat")
    for SERV in "${SERVICOS[@]}"; do
        if ! systemctl is-active --quiet "$SERV"; then
            systemctl restart "$SERV"
        fi
    done
}

# --- LOOP INFINITO DO GUARDIÃO ---
while true; do
    verificar_recursos_sistema
    ativa_dns
    verificar_servicos
    rastrear_clientes_vpn
    verificar_cota_vps
    monitor_vpn
    sleep 50
done
