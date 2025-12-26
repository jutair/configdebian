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
    # 1. Carrega o Admin cadastrado para garantir a verificação
    [ -f "$ADMIN_CONF" ] && source "$ADMIN_CONF"
    
    local USUARIO_ATUAL=$(logname 2>/dev/null || whoami)
    local DATA_ATUAL=$(date +'%d/%m/%Y')
    local HORA_ATUAL=$(date +'%H:%M:%S')

    # 🛡️ VERIFICAÇÃO DE PERMISSÃO: Apenas o Admin definido no arquivo conf
    if [[ "$USUARIO_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "Tentativa de alteração do servidor por: ${AMARELO}$USUARIO_ATUAL${NC}"
        
        # Alerta ao Telegram
        if [ -f "$TELEGRAM_CONF" ]; then
            source "$TELEGRAM_CONF"
            MENSAGEM="🚨 <b>TENTATIVA DE ALTERAR O SERVIDOR VPN!</b>%0A<b>Usuário:</b> <code>$USUARIO_ATUAL</code>%0A<b>IP:</b> <code>$IP_CONEXAO</code>%0A<b>Data/Hora:</b> $DATA_ATUAL às $HORA_ATUAL"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        
        sleep 3
        return
    fi

    # ⚙️ INÍCIO DA CONFIGURAÇÃO (Usuário Admin Confirmado)
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "              ${VERDE}CONFIGURAÇÃO DO SERVIDOR OPENVPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    # Prepara o ambiente de diretórios e permissões públicas
    echo -e "${AMARELO}Verificando diretórios de segurança...${NC}"
    sudo mkdir -p "$DIR_CLIENTES"
    sudo mkdir -p /etc/vps_protecao/consumo_clientes
    sudo chmod 755 /etc/vps_protecao/consumo_clientes
    sudo chmod 755 /etc/vps_protecao
    sudo chmod 755 "$DIR_CLIENTES"

    if [ ! -f "/etc/openvpn/server.conf" ]; then
        echo -e "${AMARELO}O OpenVPN não está instalado.${NC}"
        read -p "Deseja instalar agora? (s/n): " INST
        if [[ "$INST" == "s" || "$INST" == "S" ]]; then
            wget https://git.io/vpn -O /root/openvpn-install.sh
            chmod +x /root/openvpn-install.sh
            bash /root/openvpn-install.sh
        fi
    else
        echo -e "${VERDE}Servidor já instalado.${NC}"
        echo -e "  [1] Menu de Gerenciamento do Instalador (Portas/Protocolos/Remover)"
        echo -e "  [2] Reinstalar Script de Instalação (Update)"
        echo -e "  [0] Voltar"
        read -n 1 -p " Escolha: " OP_SVR; echo ""
        case $OP_SVR in
            1) bash /root/openvpn-install.sh ;;
            2) wget https://git.io/vpn -O /root/openvpn-install.sh && chmod +x /root/openvpn-install.sh && echo -e "\n${VERDE}Atualizado!${NC}" && sleep 2 ;;
            *) return ;;
        esac
    fi
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
    # Localiza o arquivo de status dinamicamente
    STATUS_LOG=$(grep -r "status " /etc/openvpn/server/*.conf 2>/dev/null | awk '{print $2}' | head -n1)
    STATUS_LOG=${STATUS_LOG:-"/etc/openvpn/server/openvpn-status.log"}

    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS OPENVPN ONLINE${NC}"
    echo -e "${AZUL}===============================================================${NC}"

    if [ ! -f "$STATUS_LOG" ]; then
        echo -e "${VERMELHO}Erro: Arquivo de status não encontrado!${NC}"
        echo -e "Certifique-se que o OpenVPN está rodando."
        read -p "Pressione ENTER..." ; return
    fi

    # Cabeçalho da Tabela
    printf "${AMARELO}%-15s %-18s %-12s %-10s${NC}\n" "USUÁRIO" "IP REAL" "RECEBIDO" "ENVIADO"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"

    # Extrai os dados entre "ROUTING TABLE" e "GLOBAL STATS" ou "CLIENT_LIST"
    # Lógica para converter Bytes em MB de forma legível
    sed -n '/CLIENT_LIST/,/ROUTING TABLE/p' "$STATUS_LOG" | grep -vE "HEADER|CLIENT_LIST|ROUTING TABLE" | while IFS=',' read -r NOME IP_PORTA RECV SENT DATA; do
        
        # Limpa o IP (remove a porta)
        IP_REAL=$(echo $IP_PORTA | cut -d: -f1)

        # Converte Bytes para Megabytes (MB)
        RECV_MB=$(awk "BEGIN {printf \"%.2f\", $RECV/[1024*1024]}")
        SENT_MB=$(awk "BEGIN {printf \"%.2f\", $SENT/[1024*1024]}")

        printf "%-15s %-18s %-12s %-10s\n" "$NOME" "$IP_REAL" "${RECV_MB}MB" "${SENT_MB}MB"
    done

    echo -e "${AZUL}===============================================================${NC}"
    echo -e " Total de conexões: ${VERDE}$(grep -cv "Common Name" <(sed -n '/CLIENT_LIST/,/ROUTING TABLE/p' "$STATUS_LOG" | grep -vE "HEADER|CLIENT_LIST|ROUTING TABLE"))${NC}"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -p "Pressione ENTER para voltar..."
}
# --- FUNÇÃO: RELATÓRIO DE CONSUMO ACUMULADO ---
relatorio_consumo_acumulado() {
    clear
    PASTA_DB="/etc/vps_protecao/consumo_clientes"
    MES_ATUAL=$(date +'%m-%Y')

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
# --- FUNÇÃO: GERENCIAMENTO DE BANDA ---
gerenciar_banda() {
    clear
    # Definições de caminhos
    PASTA_CONSUMO="/etc/vps_protecao/consumo_clientes"
    MES_ATUAL=$(date +'%m-%Y')
    INTERFACE_PRINCIPAL=$(ip route | grep default | awk '{print $5}')

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
        4) listar_usuarios_online ;; # Chama a função que já criamos
        5)
            clear
            CONSUMO_JSON=$(vnstat --json m | jq -r ".interfaces[] | select(.name==\"$INTERFACE_PRINCIPAL\") | .traffic.months[0]")
            RX=$(echo "$CONSUMO_JSON" | jq -r ".rx")
            TX=$(echo "$CONSUMO_JSON" | jq -r ".tx")
            TOTAL_GB=$(echo "($RX + $TX) / 1024 / 1024 / 1024" | bc -l | xargs printf "%.2f")
            
            echo -e "${AZUL}===============================================================${NC}"
            echo -e "              ${VERDE}STATUS DA COTA GLOBAL (900GB)${NC}"
            echo -e "${AZUL}===============================================================${NC}"
            echo -e " Interface: $INTERFACE_PRINCIPAL | Consumo: ${AMARELO}$TOTAL_GB GB${NC}"
            
            # Barra de progresso
            PORC=$(echo "($TOTAL_GB * 100) / 900" | bc)
            echo -ne " [ "
            for i in {1..20}; do
                if [ $((i*5)) -le $PORC ]; then echo -ne "${VERDE}#${NC}"; else echo -ne "."; fi
            done
            echo -e " ] $PORC%"
            read -p "Pressione ENTER..."
            ;;
        6)
            clear
            echo -e "${AZUL}===============================================================${NC}"
            echo -e "          ${VERDE}CONSUMO MENSAL ACUMULADO POR CLIENTE${NC}"
            echo -e "                Mês de Referência: $MES_ATUAL"
            echo -e "${AZUL}===============================================================${NC}"
            printf "${AMARELO}%-18s %-15s %-15s${NC}\n" "CLIENTE" "DOWNLOAD" "UPLOAD"
            echo -e "${AZUL}---------------------------------------------------------------${NC}"
            
            # Busca arquivos criados pelo Guardião
            for arq in "$PASTA_CONSUMO"/*_${MES_ATUAL}.log; do
                if [ -f "$arq" ]; then
                    NOME=$(basename "$arq" | cut -d'_' -f1)
                    read -r BRECV BSENT DATA_ULT < "$arq"
                    
                    # Conversão humana
                    RECV_H=$(awk "BEGIN {if ($BRECV>1073741824) printf \"%.2f GB\", $BRECV/1073741824; else printf \"%.2f MB\", $BRECV/1048576}")
                    SENT_H=$(awk "BEGIN {if ($BSENT>1073741824) printf \"%.2f GB\", $BSENT/1073741824; else printf \"%.2f MB\", $BSENT/1048576}")
                    
                    printf "%-18s %-15s %-15s\n" "$NOME" "$RECV_H" "$SENT_H"
                fi
            done
            echo -e "${AZUL}---------------------------------------------------------------${NC}"
            read -p "Pressione ENTER..."
            ;;
        0) return ;;
    esac
}

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAMENTO OPENVPN PRO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 👤 Criar Usuário                  [5] ⚙️  Configurar Servidor"
    echo -e "  [2] 🗑️  Remover Usuário               [6] 📂 Listar Downloads (SCP)"
    echo -e "  [3] 📋 Listar Cadastros                [7] 📤 Enviar Telegram (Manual)"
    echo -e "  [4] 🟢 Ver Usuários Online            [8] 📊 Gerenciamento de Banda"
    echo -e "  [0] ⬅️  Voltar ao Painel Principal"
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
        0) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
