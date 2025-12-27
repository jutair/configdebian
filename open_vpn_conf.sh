#!/bin/bash

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_OVPN="/etc/openvpn/server"
DIR_CLIENTES="/root/usuarios_vpn"
ADMIN_CONF="/etc/vps_protecao/admin.conf"
TELEGRAM_CONF="/etc/vps_protecao/telegram.conf"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Cria o diretório de armazenamento dos arquivos se não existir
mkdir -p "$DIR_CLIENTES"

# --- FUNÇÃO: CONFIGURAR SERVIDOR OPENVPN ---
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

    echo -e "${AZUL}⚙️ Configurando servidor OpenVPN...${NC}"

    # --- Diretórios ---
    sudo mkdir -p "$DIR_CLIENTES" /etc/vps_protecao/consumo_clientes /etc/vps_protecao/{categorias,perfis,clientes}
    sudo chmod 755 /etc/vps_protecao /etc/vps_protecao/consumo_clientes "$DIR_CLIENTES"

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
        # Força ativação dos logs de status
        sudo sed -i '/^status /d' "$SERVER_CONF"
        sudo sed -i '/^status-version/d' "$SERVER_CONF"
        echo "status /etc/openvpn/server/openvpn-status.log" >> "$SERVER_CONF"
        echo "status-version 2" >> "$SERVER_CONF"
        systemctl restart openvpn-server@server 2>/dev/null || systemctl restart openvpn
    fi

    # --- Categorias e perfis padrão ---
    [ ! -f "/etc/vps_protecao/categorias/adultos.list" ] && echo -e "pornhub.com\nxvideos.com" > /etc/vps_protecao/categorias/adultos.list
    [ ! -f "/etc/vps_protecao/perfis/criancas.conf" ] && echo "adultos" > /etc/vps_protecao/perfis/criancas.conf

    # --- Garantir scripts client-connect / disconnect ---
    echo -e "${AZUL}🔐 Configurando scripts client-connect / client-disconnect...${NC}"
    SCRIPTS_ORIGEM="/opt/configdebian"
    CLIENT_CONNECT="$SCRIPTS_ORIGEM/client-connect.sh"
    CLIENT_DISCONNECT="$SCRIPTS_ORIGEM/client-disconnect.sh"

    if [[ ! -f "$CLIENT_CONNECT" || ! -f "$CLIENT_DISCONNECT" ]]; then
        echo -e "${VERMELHO}⚠️ Scripts não encontrados em $SCRIPTS_ORIGEM${NC}"
    else
        ALTEROU=0
        sudo cp -f "$CLIENT_CONNECT" /etc/openvpn/
        sudo cp -f "$CLIENT_DISCONNECT" /etc/openvpn/
        sudo chmod +x /etc/openvpn/client-*.sh

        if ! grep -q '^script-security 2' "$SERVER_CONF"; then
            sed -i '/^script-security/d' "$SERVER_CONF"
            echo "script-security 2" >> "$SERVER_CONF"
            ALTEROU=1
        fi
        if ! grep -q '^client-connect /etc/openvpn/client-connect.sh' "$SERVER_CONF"; then
            sed -i '/^client-connect /d' "$SERVER_CONF"
            echo "client-connect /etc/openvpn/client-connect.sh" >> "$SERVER_CONF"
            ALTEROU=1
        fi
        if ! grep -q '^client-disconnect /etc/openvpn/client-disconnect.sh' "$SERVER_CONF"; then
            sed -i '/^client-disconnect /d' "$SERVER_CONF"
            echo "client-disconnect /etc/openvpn/client-disconnect.sh" >> "$SERVER_CONF"
            ALTEROU=1
        fi

        [[ "$ALTEROU" -eq 1 ]] && {
            echo -e "${AMARELO}♻️ Reiniciando OpenVPN para aplicar scripts...${NC}"
            systemctl restart openvpn-server@server 2>/dev/null || systemctl restart openvpn
        } || echo -e "${VERDE}✅ Scripts do guardião já estavam configurados.${NC}"
    fi

    echo -e "${VERDE}✅ Configuração do servidor OpenVPN finalizada.${NC}"
}
# --- FUNÇÃO: CONFIGURAR E GERENCIAR DNSMASQ ---
# ==========================================
# FUNÇÃO: Ativar DNS da VPN com segurança
# ==========================================
ativa_dns() {
    local LOCK="/var/run/vpn_dns_ativado.lock"
    local ALERTA_LOCK="/tmp/alerta_dns_enviado"
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"

    # Se já executou, sai
    [ -f "$LOCK" ] && return 0

    # Detecta interface TUN
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)
    if [[ -z "$INT_VPN" ]]; then
        # Envia alerta apenas uma vez
        if [ ! -f "$ALERTA_LOCK" ]; then
            enviar_alerta "❌ Nenhuma interface TUN detectada para a VPN!"
            touch "$ALERTA_LOCK"
        fi
        return 1
    fi

    # IP da interface TUN
    local IP_INT=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    IP_INT=${IP_INT:-"10.8.0.1"}

    # Cria DNS_CONF se não existir
    if [ ! -f "$DNS_CONF" ]; then
        cat > "$DNS_CONF" <<EOF
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
    fi

    # Verifica se configuração já existe
    if ! grep -q "^interface=$INT_VPN" "$DNS_CONF"; then
        # Remove entradas antigas
        sed -i '/^interface=/d;/^bind-interfaces/d;/^listen-address=/d' "$DNS_CONF"
        echo -e "interface=$INT_VPN\nbind-interfaces\nlisten-address=$IP_INT" | sudo tee -a "$DNS_CONF" >/dev/null

        # Reinicia dnsmasq apenas se houve mudança
        systemctl restart dnsmasq

        logger "[GUARDIAO] DNS da VPN ativado para $INT_VPN ($IP_INT)"
    fi

    # Cria lock para não repetir execução
    touch "$LOCK"
    chmod 600 "$LOCK"

    # Remove lock de alerta, se existia
    [ -f "$ALERTA_LOCK" ] && rm -f "$ALERTA_LOCK"
}

testa_velocidade() {
    clear
    # --- DETECÇÃO ROBUSTA DA INTERFACE ---
    # Busca no diretório de classes de rede do sistema (mais confiável que ip addr)
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)

    # Se falhar, tenta pelo comando IP como backup
    if [[ -z "$INT_VPN" ]]; then
        INT_VPN=$(ip link show up | grep -o 'tun[0-9]*' | head -n 1)
    fi

    if [[ -z "$INT_VPN" ]]; then
        echo -e "${VERMELHO}⚠️ ERRO: Nenhuma interface TUN ativa encontrada!${NC}"
        echo -e "${AMARELO}Certifique-se que o serviço OpenVPN está rodando.${NC}"
        echo -e "Comando para verificar: ${AZUL}systemctl status openvpn-server@server${NC}"
        read -p "Pressione ENTER para voltar..."
        return
    fi

    # --- VERIFICAÇÃO VNSTAT ---
    if ! vnstat --iflist | grep -q "$INT_VPN"; then
        echo -e "${AMARELO}Adicionando $INT_VPN ao banco de dados vnStat...${NC}"
        sudo vnstat --add -i "$INT_VPN"
        sudo systemctl restart vnstat
        sleep 2
    fi

    # --- EXECUÇÃO DO SPEEDTEST ---
    echo -e "${VERDE}✅ Interface detectada: $INT_VPN${NC}"
    
    # Pega o IP interno da tun0 (ex: 10.8.0.1)
    local IP_LOCAL=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

    echo -e "${AMARELO}Iniciando speedtest via $INT_VPN ($IP_LOCAL)...${NC}"
    
    if [[ -n "$IP_LOCAL" ]]; then
        # Tenta forçar a origem pelo IP da VPN
        speedtest-cli --source "$IP_LOCAL" || speedtest-cli
    else
        # Se não achar o IP interno, roda o padrão
        speedtest-cli
    fi
    
    read -p "Pressione ENTER..."
}
consumo_tun0d() {
    clear
    # Busca a interface TUN ativa
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)

    if [[ -z "$INT_VPN" ]]; then
        echo -e "${VERMELHO}⚠️ NENHUMA INTERFACE TUN ATIVA NO MOMENTO!${NC}"
        read -p "Pressione ENTER..."
        return
    fi

    # Garante que a interface esteja no vnStat sem usar o parâmetro -u
    if ! vnstat -i "$INT_VPN" >/dev/null 2>&1; then
        echo -e "${AMARELO}Adicionando $INT_VPN ao monitoramento...${NC}"
        vnstat --add -i "$INT_VPN"
        systemctl restart vnstat
        sleep 2
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           📊 CONSUMO DIÁRIO - INTERFACE $INT_VPN"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Tenta exibir. Se não houver dados, mostra mensagem amigável
    if ! vnstat -i "$INT_VPN" -d | grep -q "bytes"; then
        echo -e "${AMARELO}O banco de dados foi criado agora.${NC}"
        echo -e "Aguarde alguns minutos de uso da VPN para ver os gráficos."
    else
        vnstat -i "$INT_VPN" -d
    fi
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}
consumo_tun0m() {
    clear
    # Busca a interface TUN ativa
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)

    if [[ -z "$INT_VPN" ]]; then
        echo -e "${VERMELHO}⚠️ NENHUMA INTERFACE TUN ATIVA NO MOMENTO!${NC}"
        read -p "Pressione ENTER..."
        return
    fi

    # Garante que a interface esteja no vnStat sem usar o parâmetro -u
    if ! vnstat -i "$INT_VPN" >/dev/null 2>&1; then
        echo -e "${AMARELO}Adicionando $INT_VPN ao monitoramento...${NC}"
        vnstat --add -i "$INT_VPN"
        systemctl restart vnstat
        sleep 2
    fi

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           📊 CONSUMO DIÁRIO - INTERFACE $INT_VPN"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Tenta exibir. Se não houver dados, mostra mensagem amigável
    if ! vnstat -i "$INT_VPN" -d | grep -q "bytes"; then
        echo -e "${AMARELO}O banco de dados foi criado agora.${NC}"
        echo -e "Aguarde alguns minutos de uso da VPN para ver os gráficos."
    else
        vnstat -i "$INT_VPN" -m
    fi
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}
listar_cadastros() {
    clear
    local INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"
    
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}📋 LISTA GERAL DE CADASTROS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    if [ ! -f "$INDEX_FILE" ]; then
        echo -e "${VERMELHO}Erro: Arquivo de índices não encontrado.${NC}"
        echo -e "Certifique-se de que o Easy-RSA está configurado corretamente."
        read -p "Pressione ENTER..."
        return
    fi

    # Cabeçalho da Tabela
    printf "${AMARELO}%-20s %-15s %-20s${NC}\n" "USUÁRIO" "STATUS" "DATA CADASTRO"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    # Lógica de leitura do index.txt
    # V = Válido (Ativo)
    # R = Revogado (Bloqueado)
    while read -r STATUS DATA_CAD DATA_REV SERIAL NOME_DN; do
        # Extrai apenas o nome comum (CN) do campo Distinguished Name
        local NOME=$(echo "$NOME_DN" | sed -n 's/.*CN=\([^/]*\).*/\1/p')
        
        # Ignora a linha do "server"
        [[ "$NOME" == "server" ]] && continue
        [[ -z "$NOME" ]] && continue

        # Formata a data (YYMMDDHHMMSSZ -> DD/MM/YY)
        local DATA_FORMAT=$(echo "$DATA_CAD" | cut -c 1-6 | sed -r 's/(..)(..)(..)/\3\/\2\/\1/')

        if [[ "$STATUS" == "V" ]]; then
            printf "%-20s ${VERDE}%-15s${NC} %-20s\n" "$NOME" "ATIVO" "$DATA_FORMAT"
        elif [[ "$STATUS" == "R" ]]; then
            printf "%-20s ${VERMELHO}%-15s${NC} %-20s\n" "$NOME" "REVOGADO" "$DATA_FORMAT"
        fi
    done < "$INDEX_FILE"

    echo -e "${AZUL}===============================================================${NC}"
    
    # Resumo rápido
    local TOTAL_A=$(grep -c "^V" "$INDEX_FILE" | awk '{print $1 - 1}') # -1 por causa do server
    local TOTAL_R=$(grep -c "^R" "$INDEX_FILE")
    echo -e " Ativos: ${VERDE}$TOTAL_A${NC} | Revogados: ${VERMELHO}$TOTAL_R${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    read -p "Pressione ENTER para voltar..."
}
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



# --- FUNÇÃO 3: CRIAR USUÁRIO ---
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
            mv "$ARQUIVO_ORIGEM" "$DIR_CLIENTES/"
            chmod 644 "$DIR_CLIENTES/$NOVO_USER.ovpn"
            echo -e "${VERDE}Usuário criado com sucesso!${NC}"
            enviar_telegram "$DIR_CLIENTES/$NOVO_USER.ovpn" "$NOVO_USER"
        fi
    else
        echo -e "${VERMELHO}Instalador não encontrado.${NC}"
    fi
    sleep 2
}

# --- FUNÇÃO 4: REMOVER USUÁRIO ---
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

# --- FUNÇÃO 5: BLOQUEIO DE SERVIÇOS E PERFIS ---
bloq_servicos() {
    BASE="/etc/vps_protecao"
    DIR_CAT="$BASE/categorias"
    DIR_PERF="$BASE/perfis"
    DIR_CLIENT="$BASE/clientes"

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
        1) clear; echo "Categorias existentes:"; ls "$DIR_CAT" | sed 's/.list//'; read -p "ENTER..." ;;
        2) read -p "Nome da nova categoria: " CAT; [ -z "$CAT" ] && continue; nano "$DIR_CAT/$CAT.list" ;;
        3) read -p "Categoria para editar: " CAT; [ -f "$DIR_CAT/$CAT.list" ] && nano "$DIR_CAT/$CAT.list" ;;
        4) clear; echo "Perfis existentes:"; ls "$DIR_PERF" | sed 's/.conf//'; read -p "ENTER..." ;;
        5) read -p "Nome do novo perfil: " PERF; [ -z "$PERF" ] && continue; nano "$DIR_PERF/$PERF.conf" ;;
        6) read -p "Perfil para editar: " PERF; [ -f "$DIR_PERF/$PERF.conf" ] && nano "$DIR_PERF/$PERF.conf" ;;
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
            shopt -s nullglob
            for f in "$DIR_CLIENT"/*.profile; do
                CLI=$(basename "$f" .profile)
                PERF=$(cat "$f")
                echo "👤 $CLI → $PERF"
            done
            shopt -u nullglob
            read -p "ENTER..."
            ;;
        9) break ;;
        *) echo "Opção inválida"; sleep 1 ;;
        esac
    done
}
# --- FUNÇÃO 7: ENVIAR OVPN MANUAL PELO TELEGRAM ---
enviar_ovpn_telegram_manual() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           ${VERDE}ENVIAR OVPN PELO TELEGRAM (MANUAL)${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    shopt -s nullglob
    OVPN_FILES=("$DIR_CLIENTES"/*.ovpn)
    shopt -u nullglob

    if [ ${#OVPN_FILES[@]} -eq 0 ]; then
        echo -e "${AMARELO}⚠️ Nenhum arquivo .ovpn encontrado em $DIR_CLIENTES${NC}"
        sleep 2
        return
    fi

    echo -e "Arquivos disponíveis:"
    for i in "${!OVPN_FILES[@]}"; do
        FILE_NAME=$(basename "${OVPN_FILES[$i]}")
        echo "[$i] $FILE_NAME"
    done

    read -p "Escolha o número do arquivo para enviar: " IDX
    if ! [[ "$IDX" =~ ^[0-9]+$ ]] || [ "$IDX" -ge "${#OVPN_FILES[@]}" ]; then
        echo -e "${VERMELHO}Opção inválida!${NC}"
        sleep 2
        return
    fi

    ARQUIVO_SELECIONADO="${OVPN_FILES[$IDX]}"
    NOME_USER=$(basename "$ARQUIVO_SELECIONADO" .ovpn)

    if enviar_telegram "$ARQUIVO_SELECIONADO" "$NOME_USER"; then
        echo -e "${VERDE}✅ Arquivo $ARQUIVO_SELECIONADO enviado com sucesso!${NC}"
    else
        echo -e "${VERMELHO}❌ Falha ao enviar o arquivo. Verifique as configurações do Telegram.${NC}"
    fi

    sleep 2
}
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
    clear
    # Interface da VPN
    local INT_VPN="tun0"
    # Verifica se o vnStat já conhece a tun0, se não, tenta adicionar
    if ! vnstat --iflist | grep -q "$INT_VPN"; then
        echo -e "${AMARELO}Habilitando monitoramento para $INT_VPN...${NC}"
        vnstat -u -i "$INT_VPN"
        systemctl restart vnstat
        sleep 2
    fi

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
        1) testa_velocidade ;;
        2) consumo_tun0d ;;
        3) consumo_tun0m ;;
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
chama_configuracao() {
    while true; do
            clear
            echo -e "${AZUL}===============================================================${NC}"
            echo -e "             ${VERDE}⚙️  CONFIGURAÇÃO DE INFRAESTRUTURA${NC}"
            echo -e "${AZUL}===============================================================${NC}"
            echo -e "  [1] 🌐 Configurar/Instalar Servidor VPN (OpenVPN)"
            echo -e "  [2] 🛡️  Configurar DNSMASQ (Filtros e DNS da VPN)"
            echo -e "  [0] ⬅️  Retornar ao Menu Principal"
            echo -e "${AZUL}---------------------------------------------------------------${NC}"
            read -n 1 -p " Escolha uma opção: " OP_INFRA; echo ""
    
            case $OP_INFRA in
                1)
                    configurar_servidor_vpn  # Chama a função que já revisamos
                    ;;
                2)
                    configurar_dnsmasq
                    ;;
                0)
                    break
                    ;;
                *)
                    echo -e "${VERMELHO}Opção inválida!${NC}"
                    sleep 1
                    ;;
            esac
        done
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAMENTO OPENVPN PRO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 👤 Criar Usuário                  [6] 📂 Listar Downloads (SCP)"
    echo -e "  [2] 🗑️  Remover Usuário                [7] 📤 Enviar Telegram (Manual)"
    echo -e "  [3] 📋 Listar Cadastros               [8] 📊 Gerenciamento de Banda"
    echo -e "  [4] 🟢 Ver Usuários Online            [9] 🚫 Bloquear Serviços da VPN"
    echo -e "  [5] ⚙️  Configurar Servidor            [0] ⬅️ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OP; echo ""
    case $OP in
        1) criar_usuario ;;
        2) remover_usuario ;;
        3) listar_cadastros ;;
        4) listar_usuarios_online ;;
        5) chama_configuracao ;;
        6) listar_arquivos_ovpn ;;
        7) enviar_ovpn_telegram_manual ;;
        8) gerenciar_banda ;;
        9) bloq_servicos ;;
        0) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
