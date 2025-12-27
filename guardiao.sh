#!/bin/bash
# guardiao.sh - Monitoramento 24/7 de Serviços, VPN e Consumo de Banda

# ==========================================
# CONFIGURAÇÕES DE CAMINHOS E VARIÁVEIS
# ==========================================
DIR_PROT="/etc/vps_protecao"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
CONFIG_CONF="$DIR_PROT/config.conf"
PASTA_CONSUMO="$DIR_PROT/consumo_clientes"
ARQUIVO_ALERTA_BANDA="/tmp/alerta_banda_enviado"
ARQUIVO_ALERTA_RECURSOS="/tmp/alerta_recursos_enviado"
LOCK_GUARDIAO="/var/run/guardiao.lock"
LOG_FILE="/var/log/guardiao.log"
LIMITE_GB=900
LIMITE_CPU=85
LIMITE_RAM=85

# Intervalos em segundos
INTERVALO_RECURSOS=50
INTERVALO_VPN=60
INTERVALO_CLIENTES=50
INTERVALO_COTA=300
INTERVALO_SERVICOS=60

# Carrega configs
[ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"
[ -f "$CONFIG_CONF" ] && source "$CONFIG_CONF"

# Detecta interface principal (para cota global)
INTERFACE_PRIN=$(ip route | grep default | awk '{print $5}')

# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

# Logger local
log_msg() {
    local MSG="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $MSG" | tee -a "$LOG_FILE"
}

# Envio de alerta via Telegram
enviar_alerta() {
    local MSG="$1"
    if [[ -n "$TOKEN" && -n "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$MSG" \
            -d parse_mode="HTML" > /dev/null
        log_msg "[TELEGRAM] $MSG"
    fi
}

# ==========================================
# FUNÇÃO: RASTREAR CONSUMO POR CLIENTE VPN
# ==========================================
rastrear_clientes_vpn() {
    local STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
    local MES_ATUAL=$(date +'%m-%Y')

    [ ! -f "$STATUS_LOG" ] && return

    grep "^CLIENT_LIST," "$STATUS_LOG" | while IFS=',' read -r \
        TIPO NOME IP_REAL IP_VPN CAMPO_VAZIO BYTES_RECV BYTES_SENT DATA_CONEXAO TIMESTAMP RESTO; do

        [[ -z "$NOME" || "$NOME" == "Common Name" ]] && continue

        local ARQ_HIST="$PASTA_CONSUMO/${NOME}_${MES_ATUAL}.log"
        local ARQ_SESS="/tmp/${NOME}_last_session.tmp"

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

# ==========================================
# FUNÇÃO: MONITORAR COTA GLOBAL (VNSTAT)
# ==========================================
verificar_cota_vps() {
    if ! command -v jq &>/dev/null || ! command -v vnstat &>/dev/null; then return; fi
    local DATA_JSON=$(vnstat --json m 2>/dev/null)
    local RX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].rx" 2>/dev/null || echo 0)
    local TX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].tx" 2>/dev/null || echo 0)
    local TOTAL_GB=$(echo "scale=2; ($RX+$TX)/1024/1024/1024" | bc -l)

    if (( $(echo "$TOTAL_GB >= $LIMITE_GB" | bc -l) )); then
        if [ ! -f "$ARQUIVO_ALERTA_BANDA" ]; then
            enviar_alerta "🚨 <b>ALERTA DE CONSUMO VPS</b>%0A🌐 Interface: <code>$INTERFACE_PRIN</code>%0A📊 Consumo: <code>$TOTAL_GB GB</code>%0A⚠️ O limite de <b>$LIMITE_GB GB</b> foi atingido!"
            touch "$ARQUIVO_ALERTA_BANDA"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_BANDA" ] && rm -f "$ARQUIVO_ALERTA_BANDA"
    fi
}

# ==========================================
# FUNÇÃO: VERIFICAR RECURSOS DO SISTEMA
# ==========================================
verificar_recursos_sistema() {
    local USO_CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    local USO_RAM=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)

    if [ "$USO_CPU" -gt "$LIMITE_CPU" ] || [ "$USO_RAM" -gt "$LIMITE_RAM" ]; then
        local VILAO_NOME=$(ps -eo comm,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n1 | awk '{print $1}')
        local VILAO_PID=$(ps -eo pid,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n1 | awk '{print $1}')
        local VILAO_CPU=$(ps -eo %cpu --sort=-%cpu | head -n2 | tail -n1)
        local VILAO_RAM=$(ps -eo %mem --sort=-%mem | head -n2 | tail -n1)

        local STATUS_ACAO=""
        if [[ "$VILAO_NOME" != "sshd" && "$VILAO_NOME" != "bash" && "$VILAO_NOME" != "guardiao.sh" ]]; then
            kill -15 "$VILAO_PID" 2>/dev/null
            sleep 2
            kill -9 "$VILAO_PID" 2>/dev/null
            STATUS_ACAO="O processo <b>$VILAO_NOME (PID: $VILAO_PID)</b> foi encerrado para proteger o sistema."
        else
            STATUS_ACAO="O processo vilão é vital ($VILAO_NOME) e não foi encerrado automaticamente."
        fi

        if [ ! -f "$ARQUIVO_ALERTA_RECURSOS" ]; then
            enviar_alerta "⚠️ <b>ALERTA: SOBREUSO DE RECURSOS</b>%0A📊 CPU: <code>$USO_CPU%</code> | RAM: <code>$USO_RAM%</code>%0A🔥 Culpado: <code>$VILAO_NOME</code>%0A📉 Uso do Culpado: CPU $VILAO_CPU% | RAM $VILAO_RAM%%0A%0A🛡️ <b>Ação:</b> $STATUS_ACAO"
            touch "$ARQUIVO_ALERTA_RECURSOS"
        fi
    else
        [ -f "$ARQUIVO_ALERTA_RECURSOS" ] && rm -f "$ARQUIVO_ALERTA_RECURSOS"
    fi
}

# ==========================================
# FUNÇÃO: ATIVAR DNS PARA TODAS AS INTERFACES TUN
# ==========================================
ativa_dns() {
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"
    local LOCK="/var/run/vpn_dns_ativado.lock"

    # Evita duplicação
    [ -f "$LOCK" ] && return
    touch "$LOCK"

    for INT_VPN in $(ls /sys/class/net | grep '^tun'); do
        local IP_TUN=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        IP_TUN=${IP_TUN:-"10.8.0.1"}

        if ! grep -q "interface=$INT_VPN" "$DNS_CONF"; then
            sed -i '/^interface=/d;/^bind-interfaces/d;/^listen-address=/d' "$DNS_CONF"
            echo -e "interface=$INT_VPN\nbind-interfaces\nlisten-address=$IP_TUN" | sudo tee -a "$DNS_CONF" >/dev/null
            if systemctl restart dnsmasq; then
                log_msg "[GUARDIAO] DNS ativado para $INT_VPN ($IP_TUN)"
            else
                log_msg "[GUARDIAO] ⚠️ Falha ao reiniciar dnsmasq"
            fi
        fi
    done
}

# ==========================================
# FUNÇÃO: VERIFICAR SERVIÇOS CRÍTICOS
# ==========================================
verificar_servicos() {
    local SERVICOS=("openvpn-server@server" "sshd" "vnstat")
    for SERV in "${SERVICOS[@]}"; do
        if ! systemctl is-active --quiet "$SERV"; then
            log_msg "[GUARDIAO] Reiniciando serviço $SERV..."
            if ! systemctl restart "$SERV"; then
                log_msg "[GUARDIAO] ⚠️ Falha ao reiniciar $SERV"
            fi
        fi
    done
}

# ==========================================
# FUNÇÃO: MONITORAMENTO VPN E DNS
# ==========================================
monitor_vpn() {
    # --- Verifica se DNS está ativo ---
    ativa_dns
    # --- Verifica status geral da VPN ---
    INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
    DNS_CONFIGURADO=0
    if [[ -n "$INT_VPN" && -f /etc/dnsmasq.d/vpn.conf ]]; then
        if grep -q "^interface=$INT_VPN" /etc/dnsmasq.d/vpn.conf; then
            DNS_CONFIGURADO=1
        fi
    fi
    
    if [[ $DNS_CONFIGURADO -eq 0 ]]; then
        ALERTA_LOCK="/tmp/alerta_dns_enviado"
        if [ ! -f "$ALERTA_LOCK" ]; then
            enviar_alerta "❌ DNS da VPN não configurado para $INT_VPN!"
            touch "$ALERTA_LOCK"
        fi
    else
        [ -f "$ALERTA_LOCK" ] && rm -f "$ALERTA_LOCK"
    fi

}

# ==========================================
# LIMPA LOCKS EM EXIT
# ==========================================
cleanup() {
    rm -f "$LOCK_GUARDIAO" "/var/run/vpn_dns_ativado.lock"
    log_msg "[GUARDIAO] Encerrando guardião e removendo locks."
}
trap cleanup SIGTERM SIGINT EXIT

# ==========================================
# EVITA EXECUÇÃO DUPLICADA
# ==========================================
if [ -f "$LOCK_GUARDIAO" ]; then
    log_msg "[GUARDIAO] Já em execução. Saindo..."
    exit 1
fi
touch "$LOCK_GUARDIAO"

# ==========================================
# LOOP PRINCIPAL
# ==========================================
log_msg "[GUARDIAO] Iniciado..."
while true; do
    verificar_recursos_sistema
    verificar_servicos
    rastrear_clientes_vpn
    verificar_cota_vps
    monitor_vpn
    sleep 50
done
