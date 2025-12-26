#!/bin/bash
# guardiao.sh - O cérebro do sistema (Monitoramento 24/7)

# --- CONFIGURAÇÕES ---
DIR_PROT="/etc/vps_protecao"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
CONFIG_CONF="$DIR_PROT/config.conf"
ARQUIVO_ALERTA_BANDA="/tmp/alerta_banda_enviado"
LIMITE_GB=900

# Carrega variáveis
[ -f "$TELEGRAM_CONF" ] && source "$TELEGRAM_CONF"
[ -f "$CONFIG_CONF" ] && source "$CONFIG_CONF"

# Detecta interface principal de rede
INTERFACE_PRINCIPAL=$(ip route | grep default | awk '{print $5}')

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

# --- FUNÇÃO: MONITORAR BANDA (900GB) ---
verificar_banda_mensal() {
    # Garante que o vnstat está rodando
    if ! command -v vnstat &>/dev/null; then return; fi
    
    # Extrai consumo total do mês (rx + tx) em GB usando vnstat e jq
    # Nota: vnstat reporta em KiB no JSON, convertemos para GB
    CONSUMO_ATUAL=$(vnstat --json m | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRINCIPAL\") | .traffic.months[0] | (.rx + .tx) / 1024 / 1024 / 1024" 2>/dev/null || echo "0")
    
    # Se o consumo for maior ou igual ao limite
    if (( $(echo "$CONSUMO_ATUAL >= $LIMITE_GB" | bc -l) )); then
        # Verifica se já enviou alerta hoje para não repetir a cada minuto
        if [ ! -f "$ARQUIVO_ALERTA_BANDA" ]; then
            MENSAGEM="🚨 <b>GUARDIÃO: LIMITE DE TRÁFEGO ATINGIDO</b>%0A🌐 Interface: <code>$INTERFACE_PRINCIPAL</code>%0A📊 Consumo: <code>$(printf "%.2f" $CONSUMO_ATUAL) GB</code>%0A⚠️ Limite contratado de 900GB foi atingido!"
            enviar_alerta "$MENSAGEM"
            touch "$ARQUIVO_ALERTA_BANDA"
        fi
    else
        # Se o consumo estiver abaixo do limite (novo mês), remove o bloqueio de alerta
        [ -f "$ARQUIVO_ALERTA_BANDA" ] && rm -f "$ARQUIVO_ALERTA_BANDA"
    fi
}

# --- FUNÇÃO: MONITORAR PROCESSOS CRÍTICOS ---
verificar_servicos() {
    local SERVICOS=("openvpn" "sshd" "fail2ban")
    for SERV in "${SERVICOS[@]}"; do
        if ! systemctl is-active --quiet "$SERV"; then
            systemctl restart "$SERV"
            enviar_alerta "🛠️ <b>GUARDIÃO:</b> O serviço <code>$SERV</code> estava parado e foi reiniciado automaticamente."
        fi
    done
}

# --- LOOP PRINCIPAL ---
while true; do
    verificar_servicos
    verificar_banda_mensal
    
    # Dorme por 60 segundos antes da próxima checagem
    sleep 60
done
