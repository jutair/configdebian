# ... (início do script igual)

# Varre processos usando comando compatível
/bin/ps --no-headers -eo pid,user,pcpu,uid | while read -r PID USER CPU UID_USER; do
    
    # Remove qualquer ponto decimal da CPU para comparação (ex: 99.9 vira 99)
    CPU_INT=${CPU%.*}

    # Verifica se CPU é maior que 80 e UID maior ou igual a 1000
    if [ "$CPU_INT" -gt 80 ] && [ "$UID_USER" -ge 1000 ]; then
        
        # Mata o processo
        /bin/kill -9 "$PID"
        
        # Mensagem para o Log e Telegram
        MSG="⚠️ $(date '+%H:%M:%S') - USUÁRIO: $USER | PID: $PID | CPU: $CPU_INT%"
        echo "$MSG" >> "$LOG_FILE"
        
        enviar_telegram "<b>🚨 PROCESSO ENCERRADO</b>%0A<b>Usuário:</b> $USER%0A<b>CPU:</b> $CPU_INT%%0A<b>PID:</b> $PID"
    fi
done
