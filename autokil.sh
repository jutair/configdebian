# --- CARREGA CONFIGURAÇÕES (FORÇADO NO TOPO) ---
CONF_FILE="/etc/vps_protecao/telegram.conf"
if [ -f "$CONF_FILE" ]; then
    # O 'export' é vital para que o curl enxergue as variáveis
    export $(grep -v '^#' "$CONF_FILE" | xargs)
fi

enviar_telegram() {
    local msg="$1"
    # Usamos o caminho completo do curl e timeout de 10s para não travar o script
    /usr/bin/curl -s --connect-timeout 10 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
         -d "chat_id=${ID_CHAT}" \
         -d "text=${msg}" \
         -d "parse_mode=HTML" > /dev/null 2>&1
}

# ... (dentro do seu loop while true, onde monta a mensagem) ...

        # 📱 MONTAGEM DA MENSAGEM COM IP FIXO (EVITA CONSULTA LENTA)
        # Pegamos o IP uma vez antes do loop para não atrasar o envio
        IP_EXTERNO=$(hostname -I | awk '{print $1}') 
        NOME_VPS=$(hostname)
        
        MENSAGEM="🚨 <b>ABUSO DETECTADO</b>%0A🌐 <b>VPS:</b> <code>$NOME_VPS ($IP_EXTERNO)</code>%0A👤 <b>Usuário:</b> <code>$USER_ALVO</code>%0A📊 <b>Uso:</b> <code>$STATUS_TOTAL</code>"
        
        enviar_telegram "$MENSAGEM"
