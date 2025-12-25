#!/bin/bash

# Carrega configs do Telegram
[ -f "/etc/vps_protecao/telegram.conf" ] && source "/etc/vps_protecao/telegram.conf"

LIMITE=35

# O segredo está no --no-headers para não vir a palavra "USER" ou "%CPU"
# E filtramos para pegar apenas processos que NÃO sejam root
ALVO=$(ps -aux --sort=-%cpu --no-headers | grep -v "root" | head -n 1)

if [ -z "$ALVO" ]; then
    echo "Nenhum processo de usuário comum encontrado."
    exit 0
fi

# Extração dos dados
USER_ALVO=$(echo $ALVO | awk '{print $1}')
PID_ALVO=$(echo $ALVO | awk '{print $2}')
# Pega a CPU e remove qualquer ponto decimal
CPU_ALVO=$(echo $ALVO | awk '{print $3}' | cut -d. -f1)
PROC_ALVO=$(echo $ALVO | awk '{print $11}')

# Debug na tela
echo "Analizando: Usuário[$USER_ALVO] PID[$PID_ALVO] CPU[$CPU_ALVO%]"

# Verifica se CPU_ALVO é um número antes de comparar
if [[ "$CPU_ALVO" =~ ^[0-9]+$ ]]; then
    if [ "$CPU_ALVO" -gt "$LIMITE" ]; then
        echo "⚠️ Matando processo $PID_ALVO de $USER_ALVO ($CPU_ALVO%)..."
        
        kill -9 $PID_ALVO
        
        # Alerta Telegram
        MENSAGEM="🚨 <b>AUTO-KILL</b>%0A👤 <b>Usuário:</b> $USER_ALVO%0A⚡ <b>CPU:</b> $CPU_ALVO%25%0A🔍 <b>Processo:</b> $PROC_ALVO"
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        
        echo "$(date) - MORTO: $USER_ALVO ($CPU_ALVO%)" >> /var/log/vps_autokill.log
        wall "AUTO-KILL: Processo de $USER_ALVO encerrado."
    else
        echo "✅ Consumo de $CPU_ALVO% está abaixo do limite ($LIMITE%)."
    fi
else
    echo "Erro: Não foi possível capturar um valor numérico para a CPU."
fi
