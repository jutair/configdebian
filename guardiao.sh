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

    if [ -f "$STATUS_LOG" ]; then
        # Extrai: Common Name ($2), Bytes Received ($6), Bytes Sent ($7)
        grep "^CLIENT_LIST," "$STATUS_LOG" | while IFS=',' read -r TIPO NOME IP RECV SENT RESTO; do
            
            if [[ "$NOME" != "Common Name" && -n "$NOME" ]]; then
                ARQUIVO_HISTORICO="$PASTA_LOGS/${NOME}_${MES_ATUAL}.log"
                ARQUIVO_SESSAO="/tmp/${NOME}_last_session.tmp"

                # Cria os arquivos se não existirem
                [ ! -f "$ARQUIVO_HISTORICO" ] && echo "0 0" > "$ARQUIVO_HISTORICO"
                [ ! -f "$ARQUIVO_SESSAO" ] && echo "0 0" > "$ARQUIVO_SESSAO"

                # Lê o acumulado total e o último registro da sessão atual
                read -r ACC_RECV ACC_SENT < "$ARQUIVO_HISTORICO"
                read -r LAST_RECV LAST_SENT < "$ARQUIVO_SESSAO"

                # Lógica de Diferença:
                # Se RECV < LAST_RECV, o usuário reconectou e o contador resetou no OpenVPN
                if [ "$RECV" -lt "$LAST_RECV" ]; then
                    DIFF_RECV=$RECV
                    DIFF_SENT=$SENT
                else
                    DIFF_RECV=$((RECV - LAST_RECV))
                    DIFF_SENT=$((SENT - LAST_SENT))
                fi

                # Soma a diferença ao acumulado total do mês
                NOVO_ACC_RECV=$((ACC_RECV + DIFF_RECV))
                NOVO_ACC_SENT=$((ACC_SENT + DIFF_SENT))

                # Salva o novo total no arquivo que o Dashboard lê
                echo "$NOVO_ACC_RECV $NOVO_ACC_SENT" > "$ARQUIVO_HISTORICO"
                
                # Guarda o estado atual para a próxima comparação em 30 segundos
                echo "$RECV $SENT" > "$ARQUIVO_SESSAO"
            fi
        done
    fi
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

# --- LOOP INFINITO DO GUARDIÃO ---
while true; do
    verificar_recursos_sistema
    verificar_servicos
    rastrear_clientes_vpn
    verificar_cota_vps
    sleep 30
done

