#!/bin/bash

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_OVPN="/etc/openvpn/server"
DIR_CLIENTES="/root/usuarios_vpn"
ADMIN_CONF="/etc/vps_protecao/admin.conf"
TELEGRAM_CONF="/etc/vps_protecao/telegram.conf"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Cria o diretório de armazenamento dos arquivos se não existir
mkdir -p "$DIR_CLIENTES"

# --- FUNÇÃO 1: ENVIAR TELEGRAM (CORE) ---
enviar_telegram() {
    local ARQUIVO=$1
    local NOME_USER=$2
    
    if [ -f "$TELEGRAM_CONF" ]; then
        source "$TELEGRAM_CONF"
        if [[ -n "$TOKEN" && -f "$ARQUIVO" ]]; then
            MENSAGEM="✅ <b>ARQUIVO VPN DISPONÍVEL</b>%0A👤 Usuário: <code>$NOME_USER</code>%0A📅 Data: $(date +'%d/%m/%Y')%0A⏰ Hora: $(date +'%H:%M:%S')"
            
            # Envia aviso
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
            
            # Envia o documento .ovpn
            curl -s -F chat_id="$ID_CHAT" -F document=@"$ARQUIVO" \
                "https://api.telegram.org/bot$TOKEN/sendDocument" > /dev/null
            return 0
        fi
    fi
    return 1
}

# --- FUNÇÃO 2: CONFIGURAR SERVIDOR ---
configurar_servidor_vpn() {
    clear
    [ -f "$ADMIN_CONF" ] && source "$ADMIN_CONF"

    local USUARIO_ATUAL=$(logname 2>/dev/null || whoami)
    local DATA_ATUAL=$(date +'%d/%m/%Y')
    local HORA_ATUAL=$(date +'%H:%M:%S')

    # 🛡️ Verifica se é admin
    if [[ "$USUARIO_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️${NC}"
        if [ -f "$TELEGRAM_CONF" ]; then
            source "$TELEGRAM_CONF"
            MENSAGEM="🚨 <b>TENTATIVA DE ALTERAR O SERVIDOR VPN!</b>%0A<b>Usuário:</b> <code>$USUARIO_ATUAL</code>%0A<b>Data/Hora:</b> $DATA_ATUAL às $HORA_ATUAL"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                 -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3
        return
    fi

    echo -e "${AZUL}CONFIGURAÇÃO DO SERVIDOR OPENVPN${NC}"

    # --- Diretórios ---
    sudo mkdir -p "$DIR_CLIENTES" /etc/vps_protecao/consumo_clientes /etc/vps_protecao/{categorias,perfis,clientes}
    sudo chmod 755 /etc/vps_protecao /etc/vps_protecao/consumo_clientes "$DIR_CLIENTES"

    # --- DNSMASQ ---
    [ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak.$(date +%F-%H%M)
    cat > /etc/dnsmasq.conf <<'EOF'
conf-dir=/etc/dnsmasq.d
EOF

    cat > /etc/dnsmasq.d/vpn.conf <<'EOF'
interface=tun0
bind-interfaces
listen-address=10.8.0.1
no-resolv
server=1.1.1.1
server=8.8.8.8
cache-size=5000
domain-needed
bogus-priv
stop-dns-rebind
rebind-localhost-ok
log-queries
log-facility=/var/log/dnsmasq.log
EOF

    touch /var/log/dnsmasq.log
    chmod 644 /var/log/dnsmasq.log
    systemctl enable dnsmasq
    systemctl restart dnsmasq

    # --- OpenVPN ---
    SERVER_CONF="/etc/openvpn/server.conf"
    [ ! -f "$SERVER_CONF" ] && SERVER_CONF="/etc/openvpn/server/server.conf"

    if [ ! -f "$SERVER_CONF" ]; then
        echo -e "${AMARELO}OpenVPN não instalado.${NC}"
        read -p "Deseja instalar agora? (s/n): " INST
        [[ "$INST" =~ ^[Ss]$ ]] && \
            wget https://git.io/vpn -O /root/openvpn-install.sh && \
            chmod +x /root/openvpn-install.sh && \
            bash /root/openvpn-install.sh
    else
        echo -e "${VERDE}Servidor já instalado.${NC}"
        read -p "Deseja forçar ativação dos logs de status? (s/n): " LOGS
        [[ "$LOGS" =~ ^[Ss]$ ]] && ativar_logs_status
    fi

    # --- Scripts client-connect / disconnect ---
    DIR_CONFIG="/opt/configdebian"
    mkdir -p "$DIR_CONFIG"
    wget -q -O "$DIR_CONFIG/client-connect.sh" "https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/client-connect.sh"
    wget -q -O "$DIR_CONFIG/client-disconnect.sh" "https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/client-disconnect.sh"
    mv "$DIR_CONFIG/client-connect.sh" /etc/openvpn/client-connect.sh
    mv "$DIR_CONFIG/client-disconnect.sh" /etc/openvpn/client-disconnect.sh
    chmod 755 /etc/openvpn/client-connect.sh /etc/openvpn/client-disconnect.sh
    chown root:root /etc/openvpn/client-connect.sh /etc/openvpn/client-disconnect.sh

    # --- Ativa logs de status ---
    ativar_logs_status() {
        [ -f "$SERVER_CONF" ] || return
        sudo sed -i '/^status /d' "$SERVER_CONF"
        sudo sed -i '/^status-version/d' "$SERVER_CONF"
        echo "status /etc/openvpn/server/openvpn-status.log" >> "$SERVER_CONF"
        echo "status-version 2" >> "$SERVER_CONF"
        systemctl restart openvpn-server@server 2>/dev/null || systemctl restart openvpn
    }

    # --- Categorias e perfis padrão ---
    DIR_CAT=/etc/vps_protecao/categorias
    DIR_PERF=/etc/vps_protecao/perfis
    DIR_CLIENT=/etc/vps_protecao/clientes
    mkdir -p "$DIR_CAT" "$DIR_PERF" "$DIR_CLIENT"

    [ ! -f "$DIR_CAT/adultos.list" ] && cat > "$DIR_CAT/adultos.list" <<EOF
pornhub.com
xvideos.com
xnxx.com
youporn.com
redtube.com
EOF

    [ ! -f "$DIR_CAT/bancos.list" ] && cat > "$DIR_CAT/bancos.list" <<EOF
bb.com.br
itau.com.br
bradesco.com.br
santander.com.br
nubank.com.br
caixa.gov.br
inter.co
EOF

    [ ! -f "$DIR_PERF/criancas.conf" ] && echo "adultos" > "$DIR_PERF/criancas.conf"
    [ ! -f "$DIR_PERF/idosos.conf" ] && echo "bancos" > "$DIR_PERF/idosos.conf"
    [ ! -f "$DIR_PERF/livre.conf" ] && : > "$DIR_PERF/livre.conf"

    echo -e "${VERDE}✅ Configuração do servidor VPN e categorias finalizada.${NC}"
}


# --- FUNÇÃO 3: LISTAR CERTIFICADOS ATIVOS ---
listar_usuarios() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}CERTIFICADOS EMITIDOS NO SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    ISSUED_DIR="/etc/openvpn/server/easy-rsa/pki/issued"
    [ ! -d "$ISSUED_DIR" ] && ISSUED_DIR="/etc/openvpn/easy-rsa/pki/issued"

    if [ -d "$ISSUED_DIR" ]; then
        ls "$ISSUED_DIR" | grep ".crt" | sed 's/.crt//' | grep -v "server" | while read -r user; do
            echo -e " 👤 Certificado: ${AMARELO}$user${NC}"
        done
    else
        echo -e "${VERMELHO}Erro: Pasta de certificados não localizada.${NC}"
    fi
    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}

# --- FUNÇÃO 4: CRIAR USUÁRIO ---
criar_usuario() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                  ${VERDE}CRIAR NOVO USUÁRIO VPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário: " NOVO_USER
    [[ -z "$NOVO_USER" ]] && return

    if [ -f "/root/openvpn-install.sh" ]; then
        export MENU_OPTION=1; export CLIENT="$NOVO_USER"; export PASS=1
        bash /root/openvpn-install.sh
        
        ARQUIVO_ORIGEM="/root/$NOVO_USER.ovpn"
        [ ! -f "$ARQUIVO_ORIGEM" ] && ARQUIVO_ORIGEM="$HOME/$NOVO_USER.ovpn"

        if [ -f "$ARQUIVO_ORIGEM" ]; then
            # Move para a nova pasta pública
            mv "$ARQUIVO_ORIGEM" "$DIR_CLIENTES/"
            
            # 🛡️ AJUSTE DE PERMISSÃO: Permite que qualquer usuário baixe o arquivo
            chmod 644 "$DIR_CLIENTES/$NOVO_USER.ovpn"
            
            echo -e "${VERDE}Usuário criado com sucesso!${NC}"
            enviar_telegram "$DIR_CLIENTES/$NOVO_USER.ovpn" "$NOVO_USER"
        fi
    else
        echo -e "${VERMELHO}Instalador não encontrado.${NC}"
    fi
    sleep 2
}

# --- FUNÇÃO 5: REMOVER USUÁRIO ---
remover_usuario() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                  ${VERMELHO}REMOVER USUÁRIO VPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário para remover: " USER_DEL
    [[ -z "$USER_DEL" ]] && return

    if [ -f "/root/openvpn-install.sh" ]; then
        export MENU_OPTION=2; export CLIENT="$USER_DEL"
        bash /root/openvpn-install.sh
        rm -f "$DIR_CLIENTES/$USER_DEL.ovpn"
        echo -e "${AMARELO}Usuário e arquivo removidos.${NC}"
    fi
    sleep 2
}

# --- FUNÇÃO 6: LISTAR E GERAR LINKS SCP ---
listar_arquivos_ovpn() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}📂 GERENCIADOR DE DOWNLOADS (SCP)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    IP_EXT=$(curl -s ifconfig.me)
    mapfile -t ARQUIVOS < <(ls "$DIR_CLIENTES"/*.ovpn 2>/dev/null)

    if [ ${#ARQUIVOS[@]} -eq 0 ]; then
        echo -e "${VERMELHO}Nenhum arquivo encontrado.${NC}"; sleep 2; return
    fi

    for ((i=0; i<${#ARQUIVOS[@]}; i+=2)); do
        printf "  %-28s  %-28s\n" "$(basename "${ARQUIVOS[i]}")" "$(basename "${ARQUIVOS[i+1]}")"
    done

    echo -ne "\n${AMARELO}Digite o nome para gerar comando de download: ${NC}"
    read BUSCA
    ARQ=$(ls "$DIR_CLIENTES"/*"$BUSCA"*.ovpn 2>/dev/null | head -n 1)

    if [ -f "$ARQ" ]; then
        echo -e "\n${VERDE}🐧 Linux/Mac:${NC}\nscp $USER_LOGADO@$IP_EXT:$ARQ ~/Downloads/"
        echo -e "\n${VERDE}🪟 Windows:${NC}\nscp $USER_LOGADO@$IP_EXT:$ARQ \$env:USERPROFILE\Downloads\\"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -p "Pressione ENTER..."
    fi
}

enviar_ovpn_telegram_manual() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}📤 REENVIAR VIA TELEGRAM${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    # 1. Carrega e verifica se existem arquivos
    mapfile -t ARQUIVOS < <(ls "$DIR_CLIENTES"/*.ovpn 2>/dev/null)
    
    if [ ${#ARQUIVOS[@]} -eq 0 ]; then
        echo -e "${VERMELHO}Nenhum arquivo .ovpn encontrado em: $DIR_CLIENTES${NC}"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -p "Pressione ENTER para voltar..."
        return
    fi

    # 2. Exibe a lista de arquivos disponíveis na tela
    echo -e "${AMARELO}Arquivos disponíveis na pasta:${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    for ((i=0; i<${#ARQUIVOS[@]}; i+=2)); do
        arq1=$(basename "${ARQUIVOS[i]}")
        # Verifica se existe um segundo arquivo para a coluna ao lado
        if [ -n "${ARQUIVOS[i+1]}" ]; then
            arq2=$(basename "${ARQUIVOS[i+1]}")
            printf "  %-28s  %-28s\n" "$arq1" "$arq2"
        else
            printf "  %-28s\n" "$arq1"
        fi
    done

    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    # 3. Solicita o nome com a lista ainda visível acima
    echo -ne "${AMARELO}Digite o nome do cliente para enviar: ${NC}"
    read BUSCA

    # Sai se a busca estiver vazia
    [[ -z "$BUSCA" ]] && return

    # 4. Localiza o arquivo correspondente
    ARQ=$(ls "$DIR_CLIENTES"/*"$BUSCA"*.ovpn 2>/dev/null | head -n 1)

    if [ -f "$ARQ" ]; then
        NOME_ARQ=$(basename "$ARQ")
        echo -e "${VERDE}Enviando $NOME_ARQ...${NC}"
        
        # Chama a função de envio do Telegram
        enviar_telegram "$ARQ" "$NOME_ARQ"
        
        if [ $? -eq 0 ]; then
            echo -e "${VERDE}✅ Arquivo enviado com sucesso!${NC}"
        else
            echo -e "${VERMELHO}❌ Falha ao enviar para o Telegram.${NC}"
        fi
    else
        echo -e "${VERMELHO}Arquivo não encontrado para o termo: $BUSCA${NC}"
    fi

    sleep 2
}
# --- MENU LOCAL ---
listar_usuarios_online() {
    clear
    # 1. Localiza o log de forma silenciosa
    STATUS_LOG=""
    # Tenta caminhos comuns, jogando erros para o limbo (2>/dev/null)
    if [ -f "/etc/openvpn/server.conf" ]; then
        STATUS_LOG=$(grep -E "^status " /etc/openvpn/server.conf 2>/dev/null | awk '{print $2}')
    elif [ -f "/etc/openvpn/server/server.conf" ]; then
        STATUS_LOG=$(grep -E "^status " /etc/openvpn/server/server.conf 2>/dev/null | awk '{print $2}')
    fi

    # Se não encontrou no config, define o padrão absoluto
    [[ -z "$STATUS_LOG" ]] && STATUS_LOG="/etc/openvpn/server/openvpn-status.log"

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS OPENVPN ONLINE${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Erro: Arquivo de status não encontrado!${NC}"
        echo -e "Caminho esperado: $STATUS_LOG"
        read -p "Pressione ENTER..." ; return
    fi

    printf "${AMARELO}%-15s %-18s %-12s %-10s${NC}\n" "USUÁRIO" "IP REAL" "RECEBIDO" "ENVIADO"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    local TOTAL_CON=0

    # 2. Processamento robusto do log
    while IFS=',' read -r TIPO NOME IP_PORTA REAL_IP RECV SENT DATA_RAW; do
        # Filtra apenas linhas de clientes e garante que RECV/SENT sejam números
        if [[ "$TIPO" == "CLIENT_LIST" && "$NOME" != "Common Name" ]]; then
            
            # Garante que se RECV ou SENT estiverem vazios, virem 0 para não quebrar o awk
            [[ -z "$RECV" || "$RECV" == " " ]] && RECV=0
            [[ -z "$SENT" || "$SENT" == " " ]] && SENT=0

            # Cálculo de MB (usando printf do awk para evitar runaway regex)
            RECV_MB=$(awk "BEGIN { printf \"%.2f\", $RECV / 1048576 }")
            SENT_MB=$(awk "BEGIN { printf \"%.2f\", $SENT / 1048576 }")
            
            # Limpa a porta do IP
            IP_LMP=$(echo "$IP_PORTA" | cut -d: -f1)

            printf "%-15s %-18s %-12s %-10s\n" "$NOME" "$IP_LMP" "${RECV_MB}MB" "${SENT_MB}MB"
            ((TOTAL_CON++))
        fi
    done < "$STATUS_LOG"

    echo -e "${AZUL}===============================================================${NC}"
    echo -e " Total de conexões ativas: ${VERDE}$TOTAL_CON${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p "Pressione ENTER para voltar..."
}
# --- FUNÇÃO: RELATÓRIO DE CONSUMO ACUMULADO ---
relatorio_consumo_acumulado() {
    clear
    PASTA_DB="/etc/vps_protecao/consumo_clientes"
    MES_ATUAL=$(date +'%m-%Y')
    # Dentro da função relatorio_consumo_detalhado
    read -r BRECV BSENT < "$arq"
    
    # Inverte SENT e RECV para a perspectiva do CLIENTE:
    # SENT do servidor = DOWNLOAD do cliente
    # RECV no servidor = UPLOAD do cliente
    DOWNLOAD_H=$(awk "BEGIN { if ($BSENT >= 1073741824) printf \"%.2f GB\", $BSENT/1073741824; else printf \"%.2f MB\", $BSENT/1048576 }")
    UPLOAD_H=$(awk "BEGIN { if ($BRECV >= 1073741824) printf \"%.2f GB\", $BRECV/1073741824; else printf \"%.2f MB\", $BRECV/1048576 }")
    
    printf "%-18s %-15s %-15s\n" "$NOME" "$DOWNLOAD_H" "$UPLOAD_H"

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "              ${VERDE}RELATÓRIO DE CONSUMO MENSAL ($MES_ATUAL)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    printf "${AMARELO}%-15s %-15s %-15s${NC}\n" "CLIENTE" "DOWNLOAD" "UPLOAD"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    for arq in "$PASTA_DB"/*_${MES_ATUAL}.log; do
        [ ! -e "$arq" ] && break
        
        NOME=$(basename "$arq" | cut -d'_' -f1)
        # Lê os bytes salvos
        read -r RECV SENT DIA < "$arq"

        # Converte para MB ou GB
        RECV_H=$(awk "BEGIN {if ($RECV>1073741824) printf \"%.2f GB\", $RECV/1073741824; else printf \"%.2f MB\", $RECV/1048576}")
        SENT_H=$(awk "BEGIN {if ($SENT>1073741824) printf \"%.2f GB\", $SENT/1073741824; else printf \"%.2f MB\", $SENT/1048576}")

        printf "%-15s %-15s %-15s\n" "$NOME" "$RECV_H" "$SENT_H"
    done

    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}

relatorio_consumo_detalhado() {
    clear
    PASTA_CONSUMO="/etc/vps_protecao/consumo_clientes"
    MES_ATUAL=$(date +'%m-%Y')
    ARQUIVO_CSV="/tmp/consumo_${MES_ATUAL}.csv"
    
    # Cores para o layout
    local CYAN='\033[0;36m'
    local GOLD='\033[1;33m'
    local VERDE='\033[0;32m'
    local AMARELO='\033[1;33m'
    local VERMELHO='\033[0;31m'
    local NC='\033[0m'
    
    # Carrega configurações do Telegram
    [ -f "/etc/vps_protecao/telegram.conf" ] && source "/etc/vps_protecao/telegram.conf"

    echo -e "${CYAN}===============================================================${NC}"
    echo -e "           ${GOLD}📊 RELATÓRIO DE CONSUMO (${MES_ATUAL})${NC}"
    echo -e "${CYAN}===============================================================${NC}"
    printf "${GOLD}%-18s %-15s %-15s${NC}\n" "CLIENTE" "DOWNLOAD" "UPLOAD"
    echo -e "${CYAN}---------------------------------------------------------------${NC}"

    # Cabeçalho do CSV
    echo "Cliente,Download (Bytes),Upload (Bytes),Download (Formatado),Upload (Formatado)" > "$ARQUIVO_CSV"

    # shopt evita erros se não houver arquivos .log na pasta
    shopt -s nullglob
    for arq in "$PASTA_CONSUMO"/*_${MES_ATUAL}.log; do
        # Extrai o nome do cliente do nome do arquivo
        NOME=$(basename "$arq" | cut -d'_' -f1)
        
        # Lê os valores ACUMULADOS (Gerados pelo script Guardião)
        # Formato esperado no arquivo: "RECEBIDOS ENVIADOS"
        read -r BRECV BSENT < "$arq"
        
        # Validação para garantir que são números e evitar erros no awk
        [[ ! "$BRECV" =~ ^[0-9]+$ ]] && BRECV=0
        [[ ! "$BSENT" =~ ^[0-9]+$ ]] && BSENT=0

        # --- LÓGICA DE PERSPECTIVA DO CLIENTE ---
        # SENT (Enviado pelo servidor) = DOWNLOAD do cliente
        # RECV (Recebido pelo servidor) = UPLOAD do cliente
        DOWNLOAD_H=$(awk "BEGIN { if ($BSENT >= 1073741824) printf \"%.2f GB\", $BSENT/1073741824; else printf \"%.2f MB\", $BSENT/1048576 }")
        UPLOAD_H=$(awk "BEGIN { if ($BRECV >= 1073741824) printf \"%.2f GB\", $BRECV/1073741824; else printf \"%.2f MB\", $BRECV/1048576 }")
        
        # Exibição formatada no terminal
        printf "%-18s %-15s %-15s\n" "$NOME" "$DOWNLOAD_H" "$UPLOAD_H"
        
        # Alimenta o arquivo CSV (usando a mesma lógica de Download/Upload)
        echo "$NOME,$BSENT,$BRECV,$DOWNLOAD_H,$UPLOAD_H" >> "$ARQUIVO_CSV"
    done
    shopt -u nullglob

    echo -e "${CYAN}---------------------------------------------------------------${NC}"
    echo -e "  [1] 📥 Baixar CSV | [2] 📤 Telegram | [0] ⬅️ Voltar"
    echo -e "${CYAN}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma ação: " OP_REL; echo ""

    case $OP_REL in
        1)
            DESTINO="$HOME/consumo_${MES_ATUAL}.csv"
            cp "$ARQUIVO_CSV" "$DESTINO"
            echo -e "${VERDE}✅ Relatório salvo em: ${AMARELO}$DESTINO${NC}"
            read -p "Pressione ENTER para continuar..."
            ;;
        2)
            if [[ -n "$TOKEN" && -n "$ID_CHAT" ]]; then
                echo -e "${AMARELO}Enviando relatório ao Telegram...${NC}"
                curl -s -F chat_id="$ID_CHAT" -F document=@"$ARQUIVO_CSV" \
                     -F caption="📊 Relatório VPN - Mês: $MES_ATUAL" \
                     "https://api.telegram.org/bot$TOKEN/sendDocument" > /dev/null
                echo -e "${VERDE}✅ Relatório enviado com sucesso!${NC}"
            else
                echo -e "${VERMELHO}❌ Erro: Token ou ID do Telegram não configurados.${NC}"
            fi
            read -p "Pressione ENTER para continuar..."
            ;;
        *)
            return
            ;;
    esac
}

gerenciar_banda() {
    clear
    # Detecta a interface de rede principal (ex: eth0 ou ens3)
    INTERFACE_PRINCIPAL=$(ip route | grep default | awk '{print $5}')
    # Garante que a variável não seja vazia (fallback para eth0)
    [[ -z "$INTERFACE_PRINCIPAL" ]] && INTERFACE_PRINCIPAL="eth0"
    
    # Definições de caminhos
    PASTA_CONSUMO="/etc/vps_protecao/consumo_clientes"
    MES_ATUAL=$(date +'%m-%Y')

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}📊 GERENCIAMENTO DE BANDA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] ⚡ Testar Velocidade (tun0)"
    echo -e "  [2] 📅 Ver Consumo Diário (VPS)"
    echo -e "  [3] 🗓️  Ver Consumo Mensal (VPS)"
    echo -e "  [4] 🟢 Usuários Online Agora"
    echo -e "  [5] 🛰️  Cota Global VPS (Limite 900GB)"
    echo -e "  [6] 👤 Consumo Acumulado por Cliente (Mês)"
    echo -e "  [0] ⬅️  Voltar"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OP_BANDA; echo ""

    case $OP_BANDA in
        1)
            echo -e "${AMARELO}Iniciando speedtest...${NC}"
            speedtest-cli --source $(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}') 2>/dev/null || speedtest-cli
            read -p "Pressione ENTER..."
            ;;
        2) vnstat -d; read -p "Pressione ENTER..." ;;
        3) vnstat -m; read -p "Pressione ENTER..." ;;
        4) listar_usuarios_online ;; 
        5)
            clear
            if ! command -v jq &>/dev/null || ! command -v bc &>/dev/null; then
                echo -e "${VERMELHO}Erro: jq ou bc não instalados.${NC}"
                read -p "Pressione ENTER..."; return
            fi

            DATA_JSON=$(vnstat --json m 2>/dev/null)
            RX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRINCIPAL\") | .traffic.months[0].rx" 2>/dev/null)
            TX=$(echo "$DATA_JSON" | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRINCIPAL\") | .traffic.months[0].tx" 2>/dev/null)
            
            [[ "$RX" == "null" || -z "$RX" ]] && RX=0
            [[ "$TX" == "null" || -z "$TX" ]] && TX=0

            TOTAL_GB=$(echo "scale=2; ($RX + $TX) / 1024 / 1024 / 1024" | bc -l)
            [[ "$TOTAL_GB" == .* ]] && TOTAL_GB="0$TOTAL_GB"
            TOTAL_GB_FORMAT=$(printf "%.2f" "$TOTAL_GB")
            
            echo -e "${AZUL}===============================================================${NC}"
            echo -e "              ${VERDE}STATUS DA COTA GLOBAL (900GB)${NC}"
            echo -e "${AZUL}===============================================================${NC}"
            echo -e " Interface: $INTERFACE_PRINCIPAL | Consumo: ${AMARELO}$TOTAL_GB_FORMAT GB${NC}"
            
            INT_GB=$(echo "$TOTAL_GB / 1" | bc 2>/dev/null || echo 0)
            PORC=$(( INT_GB * 100 / 900 ))
            
            echo -ne " [ "
            for i in {1..20}; do
                if [ $((i*5)) -le $PORC ]; then echo -ne "${VERDE}#${NC}"; else echo -ne "."; fi
            done
            echo -e " ] $PORC%"
            echo -e "${AZUL}---------------------------------------------------------------${NC}"
            read -p "Pressione ENTER..."
            ;;
        6) relatorio_consumo_detalhado ;;
        0) return ;;
    esac
}
aplicar_bloqueio() {
    # Limpa o arquivo de configuração do DNS
    echo "# Gerado automaticamente" > "$DNSMASQ_FILE"
    
    # Lê a lista e formata para o dnsmasq
    while read -r linha; do
        # Remove espaços e ignora linhas vazias ou comentários
        dom=$(echo "$linha" | xargs)
        [[ -z "$dom" || "$dom" == "#"* ]] && continue
        echo "address=/$dom/0.0.0.0" >> "$DNSMASQ_FILE"
    done < "$BLOQ_FILE"
    
    # Reinicia o serviço
    systemctl restart dnsmasq
}

bloq_servicos() {

    BASE="/etc/vps_protecao"
    DIR_CAT="$BASE/categorias"
    DIR_PERF="$BASE/perfis"
    DIR_CLIENT="$BASE/clientes"

    mkdir -p "$DIR_CAT" "$DIR_PERF" "$DIR_CLIENT"

    # ---------- CATEGORIAS PADRÃO ----------
    [ ! -f "$DIR_CAT/adultos.list" ] && cat > "$DIR_CAT/adultos.list" <<EOF
pornhub.com
xvideos.com
xnxx.com
youporn.com
redtube.com
EOF

    [ ! -f "$DIR_CAT/bancos.list" ] && cat > "$DIR_CAT/bancos.list" <<EOF
bb.com.br
itau.com.br
bradesco.com.br
santander.com.br
nubank.com.br
caixa.gov.br
inter.co
EOF

    # ---------- PERFIS PADRÃO ----------
    [ ! -f "$DIR_PERF/criancas.conf" ] && echo "adultos" > "$DIR_PERF/criancas.conf"
    [ ! -f "$DIR_PERF/idosos.conf" ] && echo "bancos" > "$DIR_PERF/idosos.conf"
    [ ! -f "$DIR_PERF/livre.conf" ] && : > "$DIR_PERF/livre.conf"

    while true; do
        clear
        echo "=========================================="
        echo " 🔒 GERENCIAMENTO DE BLOQUEIOS (VPN)"
        echo "=========================================="
        echo "1) 📂 Listar categorias"
        echo "2) ➕ Criar categoria"
        echo "3) 📝 Editar categoria"
        echo "4) 👥 Listar perfis"
        echo "5) ➕ Criar perfil"
        echo "6) 📝 Editar perfil"
        echo "7) 🧍 Associar cliente a perfil"
        echo "8) 📄 Listar clientes"
        echo "9) ⬅️  Voltar"
        echo "=========================================="
        read -p "Escolha: " OP

        case "$OP" in

        1)
            clear
            echo "Categorias existentes:"
            ls "$DIR_CAT" | sed 's/.list//'
            read -p "ENTER..."
            ;;

        2)
            read -p "Nome da nova categoria: " CAT
            [ -z "$CAT" ] && continue
            nano "$DIR_CAT/$CAT.list"
            ;;

        3)
            read -p "Categoria para editar: " CAT
            [ -f "$DIR_CAT/$CAT.list" ] && nano "$DIR_CAT/$CAT.list"
            ;;

        4)
            clear
            echo "Perfis existentes:"
            ls "$DIR_PERF" | sed 's/.conf//'
            read -p "ENTER..."
            ;;

        5)
            read -p "Nome do novo perfil: " PERF
            [ -z "$PERF" ] && continue
            nano "$DIR_PERF/$PERF.conf"
            ;;

        6)
            read -p "Perfil para editar: " PERF
            [ -f "$DIR_PERF/$PERF.conf" ] && nano "$DIR_PERF/$PERF.conf"
            ;;

        7)
            read -p "Nome do cliente (Common Name): " CLI
            read -p "Perfil (ex: criancas, idosos, livre): " PERF
            if [ -f "$DIR_PERF/$PERF.conf" ]; then
                echo "$PERF" > "$DIR_CLIENT/$CLI.profile"
                echo "✔ Cliente $CLI associado ao perfil $PERF"
            else
                echo "❌ Perfil não existe"
            fi
            read -p "ENTER..."
            ;;

        8)
            clear
            echo "Clientes e perfis:"
            for f in "$DIR_CLIENT"/*.profile 2>/dev/null; do
                CLI=$(basename "$f" .profile)
                PERF=$(cat "$f")
                echo "👤 $CLI → $PERF"
            done
            read -p "ENTER..."
            ;;

        9)
            break
            ;;

        *)
            echo "Opção inválida"
            sleep 1
            ;;
        esac
    done
}

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAMENTO OPENVPN PRO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 👤 Criar Usuário                  [5] ⚙️  Configurar Servidor"
    echo -e "  [2] 🗑️  Remover Usuário                [6] 📂 Listar Downloads (SCP)"
    echo -e "  [3] 📋 Listar Cadastros               [7] 📤 Enviar Telegram (Manual)"
    echo -e "  [4] 🟢 Ver Usuários Online            [8] 📊 Gerenciamento de Banda"
    echo -e "                                        [0] ⬅️  Voltar ao Painel Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OP; echo ""
    case $OP in
        1) criar_usuario ;;
        2) remover_usuario ;;
        3) listar_usuarios ;;
        4) listar_usuarios_online ;;
        5) configurar_servidor_vpn ;;
        6) listar_arquivos_ovpn ;;
        7) enviar_ovpn_telegram_manual ;;
        8) gerenciar_banda ;;
        9) bloq_servicos ;;
        0) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
