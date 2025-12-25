#!/bin/bash
# autokil.sh - Vigilante de CPU e Conexões
# Versão Final Estável - 25-12-2025

# 1. Configurações e Caminhos
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG_FILE="/var/log/vps_autokill.log"
CONFIG_TELEGRAM="/etc/vps_protecao/telegram.conf"

# Garante que o log exista
touch "$LOG_FILE"

# 2. Carrega Token e ID do Telegram
if [ -f "$CONFIG_TELEGRAM" ]; then
    source "$CONFIG_TELEGRAM"
fi

# 3. Função de envio para o Telegram
enviar_telegram() {
    if [[ ! -z "$TOKEN" && ! -z "$ID_CHAT" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
            -d chat_id="$ID_CHAT" \
            -d text="$1" \
            -d parse_mode="HTML" > /dev/null
    fi
}

# ---------------------------------------------------------
# MONITORAMENTO DE CPU
# ---------------------------------------------------------

# Varre processos (Ignora cabeçalho e extrai: PID, USER, %CPU, UID)
ps -Ao pid,user,pcpu,uid --no-headers | while read -r PID USER CPU UID_USER; do
    
    # Limpa a CPU: Remove ponto decimal (ex: 99.8 vira 99) e espaços
    CPU_INT=$(echo "$CPU" | cut -d. -f1 | cut -d, -f1 | tr -d ' ')
    
    # Se CPU_INT for vazio ou não for número, define como 0
    [[ ! "$CPU_INT" =~ ^[0-9]+$ ]] && CPU_INT=0

    # CRITÉRIO: CPU > 80% e USUÁRIO COMUM (UID >= 1000)
    # Nota: Se o seu usuário 'teste' tiver UID menor que 1000, ajuste o valor abaixo.
    if [ "$CPU_INT" -gt 80 ] && [ "$UID_USER" -ge 1000 ]; then
        
        # Encerra o processo
        kill -9 "$PID"
        
        # Registra no Log
        DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$DATA_HORA - MORTO: PID $PID | USER: $USER | CPU: $CPU_INT%" >> "$LOG_FILE"
        
        # Envia Alerta
        enviar_telegram "<b>🚨 PROCESSO ENCERRADO</b>%0A<b>Usuário:</b> $USER%0A<b>CPU:</b> $CPU_INT%%0A<b>PID:</b> $PID%0A<b>Data:</b> $DATA_HORA"
        
        # Notifica todos os terminais abertos
        wall "O vigilante encerrou o processo $PID de $USER (Uso excessivo: $CPU_INT%)"
    fi
done

# ---------------------------------------------------------
# MONITORAMENTO DE CONEXÕES (OPCIONAL/ADICIONAL)
# ---------------------------------------------------------
# Aqui você pode adicionar a lógica de limitar conexões por IP se desejar.
