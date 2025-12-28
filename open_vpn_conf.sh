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
verificar_status_dnsmasq() {
    clear
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"
    local VERDE='\033[0;32m'
    local AMARELO='\033[1;33m'
    local VERMELHO='\033[0;31m'
    local NC='\033[0m'

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "             🔍 DIAGNÓSTICO DO DNSMASQ & VPN"
    echo -e "${AZUL}===============================================================${NC}"

    # 1. Verifica se o serviço está ativo
    if systemctl is-active --quiet dnsmasq; then
        echo -e " Status do Serviço : ${VERDE}● ATIVO (Rodando)${NC}"
    else
        echo -e " Status do Serviço : ${VERMELHO}○ INATIVO${NC}"
        systemctl start dnsmasq >/dev/null 2>&1
    fi

    # 2. Interface VPN
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)
    if [[ -n "$INT_VPN" ]]; then
        echo -e " Interface VPN     : ${VERDE}● DETECTADA ($INT_VPN)${NC}"
    else
        echo -e " Interface VPN     : ${VERMELHO}○ NÃO DETECTADA${NC}"
    fi

    # 3. Porta 53 usando 'ss' (substituto do netstat)
    if ss -tuln | grep -q ":53 "; then
        echo -e " Porta 53 (DNS)    : ${VERDE}● ABERTA${NC}"
    else
        echo -e " Porta 53 (DNS)    : ${VERMELHO}○ FECHADA / BLOQUEADA${NC}"
        echo -e "${AMARELO}Tentando liberar porta 53 do systemd-resolved...${NC}"
        systemctl stop systemd-resolved >/dev/null 2>&1
        systemctl disable systemd-resolved >/dev/null 2>&1
        systemctl restart dnsmasq
    fi

    # 4. Validação da Configuração
    echo -e "${AZUL}----------------------- CONFIGURAÇÃO --------------------------${NC}"
    if [ -f "$DNS_CONF" ]; then
        echo -e " Arquivo vpn.conf  : ${VERDE}Encontrado${NC}"
        grep -q "interface=$INT_VPN" "$DNS_CONF" && echo -e " Vínculo Interface : ${VERDE}Correto ($INT_VPN)${NC}" || echo -e " Vínculo Interface : ${VERMELHO}Incorreto${NC}"
    else
        echo -e " Arquivo vpn.conf  : ${VERMELHO}Não encontrado${NC}"
    fi

    echo -e "${AZUL}--------------------------- LOGS ------------------------------${NC}"
    echo -e " Últimas 3 consultas processadas:"
    # Tenta ler o log padrão ou o log do systemd se o arquivo estiver vazio
    if [ -s "/var/log/dnsmasq.log" ]; then
        tail -n 3 /var/log/dnsmasq.log
    else
        journalctl -u dnsmasq --no-pager -n 3
    fi

    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}
# ==========================================
# FUNÇÃO: Ativar DNS da VPN com segurança
# ==========================================
configurar_dnsmasq_vpn() {
    local ACTION=${1:-"ativar"}  # ativar | desativar
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"
    local LOCK="/var/run/vpn_dns_ativado.lock"
    local LOG="/var/log/dnsmasq.log"
    local AMARELO='\033[1;33m'
    local VERDE='\033[0;32m'
    local VERMELHO='\033[0;31m'
    local NC='\033[0m'

    # --- ETAPA 1: DETECÇÃO AGRESSIVA DA INTERFACE ---
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)
    [ -z "$INT_VPN" ] && INT_VPN=$(ip link show up | grep -o 'tun[0-9]*' | head -n 1)

    case "$ACTION" in
        ativar)
            # Bloqueio de segurança: Só inicia se a tun existir e for funcional
            if [[ -z "$INT_VPN" ]]; then
                echo -e "${VERMELHO}❌ ERRO: tun0 não detectada! O DNSMASQ não pode ser iniciado.${NC}"
                echo -e "${AMARELO}Inicie o serviço OpenVPN primeiro.${NC}"
                return 1
            fi

            # --- ETAPA 2: FORÇAR PERMISSÕES E VNSTAT (O que funcionou) ---
            # Garante que o tráfego da interface detectada seja monitorado
            chown -R vnstat:vnstat /var/lib/vnstat 2>/dev/null
            if ! vnstat --iflist | grep -q "$INT_VPN"; then
                vnstat --add -i "$INT_VPN" >/dev/null 2>&1
                systemctl restart vnstat >/dev/null 2>&1
                sleep 1
            fi
            # Força o descarregamento de dados para o banco
            killall -HUP vnstatd >/dev/null 2>&1

            # --- ETAPA 3: CONFIGURAÇÃO DO DNS ---
            # Cria config base se não existir
            if [ ! -f "$DNS_CONF" ]; then
                cat > "$DNS_CONF" <<'EOF'
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
            fi

            touch "$LOG"
            chmod 644 "$LOG"

            # Pega o IP real da interface detectada
            local IP_INT=$(ip -4 addr show "$INT_VPN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
            IP_INT=${IP_INT:-"10.8.0.1"}

            # Limpa entradas antigas e aplica a nova interface detectada
            sed -i '/^interface=/d;/^bind-interfaces/d;/^listen-address=/d' "$DNS_CONF"
            {
                echo "interface=$INT_VPN"
                echo "bind-interfaces"
                echo "listen-address=$IP_INT"
            } >> "$DNS_CONF"

            # Reinicia o serviço de DNS
            systemctl enable dnsmasq >/dev/null 2>&1
            if dnsmasq --test &>/dev/null; then
                systemctl restart dnsmasq
                touch "$LOCK"
                chmod 600 "$LOCK"
                echo -e "${VERDE}✅ DNSMASQ e VNSTAT sincronizados para $INT_VPN ($IP_INT)${NC}"
            else
                echo -e "${VERMELHO}❌ Erro na sintaxe do DNSMASQ. Configuração não aplicada.${NC}"
                return 1
            fi
        ;;

        desativar)
            rm -f "$LOCK"
            if [ -f "$DNS_CONF" ]; then
                sed -i '/^interface=/d;/^listen-address=/d;/^bind-interfaces/d' "$DNS_CONF"
            fi
        
            if dnsmasq --test &>/dev/null; then
                systemctl restart dnsmasq
                echo -e "${AMARELO}🟡 DNSMASQ desvinculado da VPN.${NC}"
            else
                echo -e "${VERMELHO}⚠️ Configuração inválida detectada — Corrija manualmente.${NC}"
            fi
        ;;

        *)
            echo "Uso: configurar_dnsmasq_vpn [ativar|desativar]"
            return 1
        ;;
    esac
}
verificar_dns_vpn() {
    local DNS_CONF="/etc/dnsmasq.d/vpn.conf"
    local LOCK="/var/run/vpn_dns_ativado.lock"

    local INT_VPN
    INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n1)

    [[ -z "$INT_VPN" ]] && return 1
    [[ ! -f "$LOCK" ]] && return 1
    [[ ! -f "$DNS_CONF" ]] && return 1

    grep -q "^interface=$INT_VPN" "$DNS_CONF"
}

menu_dnsmasq_vpn() {
    while true; do
        clear
        echo "======================================="
        echo "     DNSMASQ VPN - CONTROLE MANUAL      "
        echo "======================================="
        echo "1) Ativar DNS da VPN"
        echo "2) Desativar DNS da VPN"
        echo "3) Status atual"
        echo "0) Voltar"
        echo "---------------------------------------"
        read -p "Opção: " OP

        case "$OP" in
            1)
                configurar_dnsmasq_vpn ativar
                read -p "Enter para continuar..."
            ;;
            2)
                configurar_dnsmasq_vpn desativar
                read -p "Enter para continuar..."
            ;;
            3) verificar_status_dnsmasq ;;
            0)
                break
            ;;
            *)
                echo "Opção inválida"
                sleep 1
            ;;
        esac
    done
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

    # --- CORREÇÃO DE PERMISSÃO E ATUALIZAÇÃO FORÇADA ---
    # Garante que o diretório do vnStat pertença ao usuário correto
    chown -R vnstat:vnstat /var/lib/vnstat 2>/dev/null

    # Verifica se a interface existe no banco. Se não, adiciona.
    if ! vnstat --iflist | grep -q "$INT_VPN"; then
        echo -e "${AMARELO}Configurando $INT_VPN no vnStat...${NC}"
        vnstat --add -i "$INT_VPN"
        systemctl restart vnstat
        sleep 2
    fi

    # FORÇA a atualização do banco de dados agora mesmo
    # Em versões novas do vnstat usa-se o daemon, em antigas o -u. Tentamos os dois.
    vnstat -u -i "$INT_VPN" >/dev/null 2>&1
    killall -HUP vnstatd >/dev/null 2>&1 # Força o daemon a descarregar dados no disco

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           📊 CONSUMO DIÁRIO - INTERFACE $INT_VPN"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Tenta exibir o tráfego. 
    # Usamos 'grep [0-9]' para verificar se há qualquer número de tráfego (KB, MB, GB)
    RESULTADO=$(vnstat -i "$INT_VPN" -d)
    
    if echo "$RESULTADO" | grep -qE "KiB|MiB|GiB|B"; then
        echo "$RESULTADO"
    else
        echo -e "${AMARELO}⚠️ INTERFACE DETECTADA, MAS SEM DADOS REGISTRADOS.${NC}"
        echo -e "Causa Provável: O firewall pode estar bloqueando a leitura do vnStat"
        echo -e "ou o tráfego ainda está em cache na memória."
        echo -e "\n${AZUL}DICA:${NC} Tente rodar: ${VERDE}vnstat -l -i $INT_VPN${NC} para ver o tráfego ao vivo."
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

    # --- CORREÇÃO DE PERMISSÃO E ATUALIZAÇÃO FORÇADA ---
    # Garante que o diretório do vnStat pertença ao usuário correto
    chown -R vnstat:vnstat /var/lib/vnstat 2>/dev/null

    # Verifica se a interface existe no banco. Se não, adiciona.
    if ! vnstat --iflist | grep -q "$INT_VPN"; then
        echo -e "${AMARELO}Configurando $INT_VPN no vnStat...${NC}"
        vnstat --add -i "$INT_VPN"
        systemctl restart vnstat
        sleep 2
    fi

    # FORÇA a atualização do banco de dados agora mesmo
    # Em versões novas do vnstat usa-se o daemon, em antigas o -u. Tentamos os dois.
    vnstat -u -i "$INT_VPN" >/dev/null 2>&1
    killall -HUP vnstatd >/dev/null 2>&1 # Força o daemon a descarregar dados no disco

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "           📊 CONSUMO DIÁRIO - INTERFACE $INT_VPN"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Tenta exibir o tráfego. 
    # Usamos 'grep [0-9]' para verificar se há qualquer número de tráfego (KB, MB, GB)
    RESULTADO=$(vnstat -i "$INT_VPN" -m)
    
    if echo "$RESULTADO" | grep -qE "KiB|MiB|GiB|B"; then
        echo "$RESULTADO"
    else
        echo -e "${AMARELO}⚠️ INTERFACE DETECTADA, MAS SEM DADOS REGISTRADOS.${NC}"
        echo -e "Causa Provável: O firewall pode estar bloqueando a leitura do vnStat"
        echo -e "ou o tráfego ainda está em cache na memória."
        echo -e "\n${AZUL}DICA:${NC} Tente rodar: ${VERDE}vnstat -l -i $INT_VPN${NC} para ver o tráfego ao vivo."
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
    local VERDE='\033[0;32m'
    local AMARELO='\033[1;33m'
    local VERMELHO='\033[0;31m'
    local AZUL='\033[0;34m'
    local NC='\033[0m'

    # --- 1. INFRAESTRUTURA E REPARO ---
    local INT_VPN=$(ls /sys/class/net | grep '^tun' | head -n 1)
    if [[ -z "$INT_VPN" ]]; then
        echo -e "${VERMELHO}⚠️ VPN Offline! A interface TUN não foi detectada.${NC}"
        read -p "Pressione ENTER..." ; return 1
    fi
    chown -R vnstat:vnstat /var/lib/vnstat 2>/dev/null
    killall -HUP vnstatd >/dev/null 2>&1

    # --- 2. DIRETÓRIOS ---
    local BASE="/etc/vps_protecao"
    local DIR_CAT="$BASE/categorias"
    local DIR_PERF="$BASE/perfis"
    local DIR_CLIENT="$BASE/clientes"
    local CCD="/etc/openvpn/ccd"
    local DNS_BLOQ_CONF="/etc/dnsmasq.d/bloqueios.conf"
    mkdir -p "$DIR_CAT" "$DIR_PERF" "$DIR_CLIENT" "$CCD"

    # --- 3. FUNÇÕES INTERNAS DO MOTOR ---
    
    # Gera um IP que não esteja em uso no CCD
    gerar_ip_disponivel() {
        for i in {10..250}; do
            local IP="10.8.0.$i"
            if ! grep -q "$IP" "$CCD"/* 2>/dev/null; then
                echo "$IP" ; return
            fi
        done
    }

    # Compila as Regras de Tags para o Dnsmasq
    atualizar_motor_dns_tags() {
        echo -e "${AMARELO}⚙️  Sincronizando IPs e Perfis no Dnsmasq...${NC}"
        
        # 1. Limpa e inicia o arquivo de bloqueios
        echo "# Regras Individuais - $(date)" > "$DNS_BLOQ_CONF"
        
        local CONT_REGRAS=0
        
        # 2. Mapeia Hosts e Tags
        for f in "$DIR_CLIENT"/*.profile; do
            local CLI=$(basename "$f" .profile)
            local PERF=$(cat "$f")
            local IP_CLI=$(grep "ifconfig-push" "$CCD/$CLI" 2>/dev/null | awk '{print $2}')
            
            if [ -n "$IP_CLI" ]; then
                # Define que este IP pertence a esta TAG (perfil)
                echo "dhcp-host=$CLI,$IP_CLI,set:$PERF" >> "$DNS_BLOQ_CONF"
                
                # 3. Associa Domínios às Tags
                if [ -f "$DIR_PERF/$PERF.conf" ]; then
                    for cat in $(cat "$DIR_PERF/$PERF.conf"); do
                        if [ -f "$DIR_CAT/$cat.list" ]; then
                            while read -r dom; do
                                [[ -z "$dom" || "$dom" =~ ^# ]] && continue
                                # Sintaxe Universal: Retorna 0.0.0.0 APENAS para quem tem a tag
                                echo "address=/$dom/0.0.0.0" | sed "s/$/#$PERF/" >> "$DNS_BLOQ_CONF"
                                ((CONT_REGRAS++))
                            done < "$DIR_CAT/$cat.list"
                        fi
                    done
                fi
            fi
        done

        # 4. TESTE DE SEGURANÇA ANTES DE REINICIAR
        if dnsmasq --test &>/dev/null; then
            systemctl restart dnsmasq
            echo -e "${VERDE}✅ Filtro Individual Ativo ($CONT_REGRAS regras).${NC}"
        else
            echo -e "${VERMELHO}❌ Erro de Sintaxe! Revertendo para evitar queda do DNS...${NC}"
            # Se deu erro, esvazia o arquivo de bloqueios para o DNS não cair
            > "$DNS_BLOQ_CONF"
            systemctl restart dnsmasq
            echo -e "${AMARELO}Dica: Verifique se há caracteres especiais nos nomes dos domínios.${NC}"
        fi
        sleep 2
    }
    # --- 4. MENU PRINCIPAL ---
    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "         🔒 BLOQUEIO POR PERFIL INDIVIDUAL (TAGS)"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        echo " 1) 📂 Categorias (Listas de Sites)"
        echo " 2) ➕ Criar/Editar Categoria"
        echo " 3) 👥 Perfis (Grupos de Bloqueio)"
        echo " 4) ➕ Criar/Editar Perfil"
        echo " 5) 🧍 Associar Cliente a Perfil (Gera IP Fixo)"
        echo " 6) 📄 Ver Mapa de Clientes/IPs"
        echo " 7) 🚀 APLICAR TODAS AS REGRAS"
        echo " 0) ⬅️  Voltar"
        echo -e "${AZUL}===============================================================${NC}"
        read -p " Escolha: " OP

        case "$OP" in
            1) ls "$DIR_CAT" | sed 's/.list//' ; read -p "ENTER..." ;;
            2) read -p "Categoria: " CAT; nano "$DIR_CAT/$CAT.list" ;;
            3) ls "$DIR_PERF" | sed 's/.conf//' ; read -p "ENTER..." ;;
            4) read -p "Perfil: " PERF; echo "Dica: Escreva os nomes das categorias no arquivo."; sleep 1; nano "$DIR_PERF/$PERF.conf" ;;
            5)
                read -p "Nome do Cliente (Common Name): " CLI
                [ -z "$CLI" ] && continue
                echo "Perfis: $(ls "$DIR_PERF" | sed 's/.conf//' | xargs)"
                read -p "Perfil para $CLI: " PERF
                
                if [ -f "$DIR_PERF/$PERF.conf" ]; then
                    # Salva Perfil
                    echo "$PERF" > "$DIR_CLIENT/$CLI.profile"
                    # Garante IP Fixo
                    if [ ! -f "$CCD/$CLI" ]; then
                        local NOVO_IP=$(gerar_ip_disponivel)
                        echo "ifconfig-push $NOVO_IP 255.255.255.0" > "$CCD/$CLI"
                        echo -e "${VERDE}✔ IP $NOVO_IP reservado para $CLI${NC}"
                    fi
                    echo -e "${VERDE}✔ Cliente configurado!${NC}"
                else
                    echo -e "${VERMELHO}❌ Perfil não existe.${NC}"
                fi
                read -p "ENTER..."
                ;;
            6)
                clear
                echo -e "CLIENTE | IP FIXO | PERFIL ATIVO"
                for f in "$DIR_CLIENT"/*.profile; do
                    C=$(basename "$f" .profile)
                    P=$(cat "$f")
                    I=$(grep "ifconfig-push" "$CCD/$C" 2>/dev/null | awk '{print $2}')
                    echo -e "👤 $C | 🌐 ${I:-Sem IP} | 🏷️ $P"
                done
                read -p "ENTER..."
                ;;
            7) atualizar_motor_dns_tags ;;
            0) break ;;
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
    local CONF_VPN=""
    local STATUS_LOG=""

    # 1. Tenta localizar o arquivo de configuração ativo
    if [ -f "/etc/openvpn/server/server.conf" ]; then
        CONF_VPN="/etc/openvpn/server/server.conf"
    elif [ -f "/etc/openvpn/server.conf" ]; then
        CONF_VPN="/etc/openvpn/server.conf"
    fi

    # 2. Se encontrou o config, verifica qual log está definido lá
    if [ -n "$CONF_VPN" ]; then
        STATUS_LOG=$(grep -E "^status " "$CONF_VPN" | awk '{print $2}')
    fi

    # 3. Se não houver log definido ou o arquivo não existir, criamos a configuração
    if [[ -z "$STATUS_LOG" || ! -f "$STATUS_LOG" ]]; then
        echo -e "${AMARELO}⚠️ Log de status não encontrado ou inativo.${NC}"
        echo -e "${AZUL}🛠️ Tentando configurar e ativar o log automaticamente...${NC}"
        
        if [ -n "$CONF_VPN" ]; then
            # Define um caminho padrão se estiver vazio
            [[ -z "$STATUS_LOG" ]] && STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
            
            # Remove entradas antigas para evitar duplicidade e adiciona a nova
            sed -i '/^status /d' "$CONF_VPN"
            sed -i '/^status-version/d' "$CONF_VPN"
            echo "status $STATUS_LOG" >> "$CONF_VPN"
            echo "status-version 2" >> "$CONF_VPN"
            
            # Reinicia o serviço para aplicar as mudanças
            systemctl restart openvpn-server@server 2>/dev/null || systemctl restart openvpn
            echo -e "${VERDE}✅ Configuração aplicada! Aguardando 3s para geração do arquivo...${NC}"
            sleep 3
        else
            echo -e "${VERMELHO}❌ Erro crítico: Arquivo server.conf não localizado!${NC}"
            read -p "Pressione ENTER..." ; return
        fi
    fi

    # --- INÍCIO DA EXIBIÇÃO ---
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS OPENVPN ONLINE${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}O arquivo $STATUS_LOG ainda não foi criado pelo sistema.${NC}"
        echo -e "Certifique-se de que há pelo menos um cliente tentando conectar."
        read -p "Pressione ENTER..." ; return
    fi

    printf "${AMARELO}%-15s %-18s %-12s %-10s${NC}\n" "USUÁRIO" "IP REAL" "RECEBIDO" "ENVIADO"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    local TOTAL_CON=0
    # Processa o log (formato status-version 2)
    while IFS=',' read -r TIPO NOME IP_PORTA RECV SENT DATA_RAW; do
        if [[ "$TIPO" == "CLIENT_LIST" && "$NOME" != "Common Name" ]]; then
            [[ -z "$RECV" ]] && RECV=0
            [[ -z "$SENT" ]] && SENT=0

            RECV_MB=$(awk "BEGIN { printf \"%.2f\", $RECV / 1048576 }")
            SENT_MB=$(awk "BEGIN { printf \"%.2f\", $SENT / 1048576 }")
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
                    menu_dnsmasq_vpn
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
