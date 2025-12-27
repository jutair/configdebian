#!/bin/bash
# guardiao.sh - Monitoramento 24/7 de Serviços e Consumo de Banda

# --- CONFIGURAÇÕES DE CAMINHOS ---
DIR_PROT="/etc/vps_protecao"
TELEGRAM_CONF="$DIR_PROT/telegram.conf"
CONFIG_CONF="$DIR_PROT/config.conf"
PASTA_CONSUMO="$DIR_PROT/consumo_clientes"  # Pasta criada no setup_vps.sh
ARQUIVO_ALERTA_BANDA="/tmp/alerta_banda_enviado"
LIMITE_GB=900

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

# --- FUNÇÃO: RASTREAR CONSUMO POR CLIENTE (ACUMULADO) ---
rastrear_clientes_vpn() {
    STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
    MES_ATUAL=$(date +'%m-%Y')
    PASTA_LOGS="/etc/vps_protecao/consumo_clientes"

    [ ! -f "$STATUS_LOG" ] && return

    grep "^CLIENT_LIST," "$STATUS_LOG" | while IFS=',' read -r \
    TIPO \
    NOME \
    IP_REAL \
    IP_VPN \
    CAMPO_VAZIO \
    BYTES_RECV \
    BYTES_SENT \
    DATA_CONEXAO \
    TIMESTAMP \
    RESTO
    do
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


# --- FUNÇÃO: MONITORAR COTA GLOBAL (900GB) ---
verificar_cota_vps() {
    # Verifica se as dependências instaladas no setup_vps.sh estão presentes
    if ! command -v jq &>/dev/null || ! command -v vnstat &>/dev/null; then return; fi

    # Obtém o tráfego do mês atual via vnstat em JSON
    DATA_JSON=$(vnstat --json m 2>/dev/null)
    RX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].rx" 2>/dev/null || echo 0)
    TX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRIN\") | .traffic.months[0].tx" 2>/dev/null || echo 0)

    # Cálculo do total em GB (usando bc instalado no setup_vps.sh)
    TOTAL_GB=$(echo "scale=2; ($RX + $TX) / 1024 / 1024 / 1024" | bc -l)

    # Verifica se atingiu o limite de 900GB
    if (( $(echo "$TOTAL_GB >= $LIMITE_GB" | bc -l) )); then
        if [ ! -f "$ARQUIVO_ALERTA_BANDA" ]; then
            MENSAGEM="🚨 <b>ALERTA DE CONSUMO VPS</b>%0A🌐 Interface: <code>$INTERFACE_PRIN</code>%0A📊 Consumo: <code>$TOTAL_GB GB</code>%0A⚠️ O limite de <b>900GB</b> foi atingido!"
            enviar_alerta "$MENSAGEM"
            touch "$ARQUIVO_ALERTA_BANDA"
        fi
    else
        # Se baixar do limite (ex: virada de mês), permite novo alerta
        [ -f "$ARQUIVO_ALERTA_BANDA" ] && rm -f "$ARQUIVO_ALERTA_BANDA"
    fi
}

# --- FUNÇÃO: SAÚDE DOS SERVIÇOS ---
verificar_servicos() {
    local SERVICOS=("openvpn" "sshd" "vnstat")
    for SERV in "${SERVICOS[@]}"; do
        if ! systemctl is-active --quiet "$SERV"; then
            systemctl restart "$SERV"
        fi
    done
}

# --- CONFIGURAÇÕES DE RECURSOS ---
LIMITE_CPU=85
LIMITE_RAM=85
ARQUIVO_ALERTA_RECURSOS="/tmp/alerta_recursos_enviado"

# --- FUNÇÃO: MONITORAR CPU E RAM ---
verificar_recursos_sistema() {
    # 1. Verifica Uso Global de CPU (média dos últimos segundos)
    # Pega o uso de CPU ignorando o 'id' (idle/ocioso)
    USO_CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)

    # 2. Verifica Uso Global de RAM
    USO_RAM=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)

    # Lógica de Bloqueio e Alerta
    if [ "$USO_CPU" -gt "$LIMITE_CPU" ] || [ "$USO_RAM" -gt "$LIMITE_RAM" ]; then
        
        # Identifica o processo "vilão" (o que está usando mais recursos)
        VILAO_NOME=$(ps -eo comm,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n 1 | awk '{print $1}')
        VILAO_PID=$(ps -eo pid,%cpu,%mem --sort=-%cpu | head -n 2 | tail -n 1 | awk '{print $1}')
        VILAO_CPU=$(ps -eo %cpu --sort=-%cpu | head -n 2 | tail -n 1)
        VILAO_RAM=$(ps -eo %mem --sort=-%mem | head -n 2 | tail -n 1)

        # AÇÃO: Encerrar o processo culpado para proteger a VPS
        # Evita matar processos vitais como sshd ou o próprio guardião
        if [[ "$VILAO_NOME" != "sshd" && "$VILAO_NOME" != "bash" && "$VILAO_NOME" != "guardiao.sh" ]]; then
            kill -9 "$VILAO_PID"
            STATUS_ACAO="O processo <b>$VILAO_NOME (PID: $VILAO_PID)</b> foi encerrado para proteger o sistema."
        else
            STATUS_ACAO="O processo vilão é vital ($VILAO_NOME) e não foi encerrado automaticamente."
        fi

        # Envia Alerta ao Telegram
        if [ ! -f "$ARQUIVO_ALERTA_RECURSOS" ]; then
            MENSAGEM="⚠️ <b>ALERTA: SOBREUSO DE RECURSOS</b>%0A📊 CPU: <code>$USO_CPU%</code> | RAM: <code>$USO_RAM%</code>%0A🔥 Culpado: <code>$VILAO_NOME</code>%0A📉 Uso do Culpado: CPU $VILAO_CPU% | RAM $VILAO_RAM%%0A%0A🛡️ <b>Ação:</b> $STATUS_ACAO"
            enviar_alerta "$MENSAGEM"
            touch "$ARQUIVO_ALERTA_RECURSOS"
        fi
    else
        # Reseta o alerta se os recursos voltarem ao normal
        [ -f "$ARQUIVO_ALERTA_RECURSOS" ] && rm -f "$ARQUIVO_ALERTA_RECURSOS"
    fi
}
ativa_dns() {
    #!/bin/bash
    # ==========================================
    # GUARDIÃO – ATIVA DNS DA VPN COM SEGURANÇA
    # Executado automaticamente pelo OpenVPN
    # ==========================================
    
    LOCK="/var/run/vpn_dns_ativado.lock"
    DNS_CONF="/etc/dnsmasq.d/vpn.conf"
    
    # Só executa uma vez
    [ -f "$LOCK" ] && exit 0
    
    # Confirma se tun0 existe
    if ip link show tun0 > /dev/null 2>&1; then
    
        # Evita duplicação
        if ! grep -q "^interface=tun0" "$DNS_CONF"; then
            sed -i '1iinterface=tun0\nbind-interfaces\nlisten-address=10.8.0.1\n' "$DNS_CONF"
        fi
    
        # Reinicia apenas o DNS (não derruba VPN)
        systemctl restart dnsmasq
    
        # Cria lock para não repetir
        touch "$LOCK"
        chmod 600 "$LOCK"
    
        logger "[GUARDIAO] DNS da VPN ativado com sucesso na tun0"
    
    fi
    
    exit 0

}
monitor_vpn() {
#!/bin/bash

# --- Configurações do Telegram ---
[ -f /etc/vps_protecao/telegram.conf ] && source /etc/vps_protecao/telegram.conf

# --- Funções de cores para saída ---
VERMELHO='\033[0;31m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

# --- Data/Hora ---
DATA_ATUAL=$(date +'%d/%m/%Y')
HORA_ATUAL=$(date +'%H:%M:%S')

# --- Checa status do OpenVPN ---
if systemctl is-active --quiet openvpn-server@server; then
    VPN_STATUS=1
else
    VPN_STATUS=0
fi

# --- Checa interface TUN ---
INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
if [[ -n "$INT_VPN" ]]; then
    IP_TUN=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
else
    IP_TUN=""
fi

# --- Verifica DNS ---
DNS_CONFIGURADO=0
if [[ -n "$INT_VPN" && -f /etc/dnsmasq.d/vpn.conf ]]; then
    if grep -q "interface=$INT_VPN" /etc/dnsmasq.d/vpn.conf; then
        DNS_CONFIGURADO=1
    fi
fi

# --- Relatório ---
MENSAGEM="⏱️ <b>Monitoramento VPN - $DATA_ATUAL $HORA_ATUAL</b>%0A"

if [[ $VPN_STATUS -eq 1 && -n "$INT_VPN" && $DNS_CONFIGURADO -eq 1 ]]; then
    echo -e "${VERDE}✅ VPN OK: $INT_VPN ($IP_TUN), DNS configurado.${NC}"
else
    echo -e "${VERMELHO}❌ Problema detectado na VPN!${NC}"
    [[ $VPN_STATUS -eq 0 ]] && MENSAGEM+="❌ OpenVPN não está ativo.%0A"
    [[ -z "$INT_VPN" ]] && MENSAGEM+="❌ Nenhuma interface TUN detectada.%0A"
    [[ $DNS_CONFIGURADO -eq 0 ]] && MENSAGEM+="❌ DNS não configurado para a VPN.%0A"

    # --- Envia alerta Telegram ---
    if [[ -n "$TOKEN" && -n "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
    fi
fi
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

