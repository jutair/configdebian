#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
# Garante que o caminho exista ou aponta para o diretório atual
[ ! -d "$(dirname "$INSTALLER_PATH")" ] && INSTALLER_PATH="./openvpn-install.sh"

# Verifica root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# --- FUNÇÕES DE SISTEMA ---

veri_openvpn () {
    echo -e "${AMARELO}Validando ambiente OpenVPN...${SEM_COR}"
    
    # 1. Instala dependências essenciais para os scripts funcionarem (bc, vnstat, etc)
    DEPENDENCIAS=(bc vnstat curl wget unzip speedtest-cli net-tools)
    for dep in "${DEPENDENCIAS[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${AMARELO}Instalando dependência: $dep...${SEM_COR}"
            apt-get update -qq && apt-get install -y "$dep" -y > /dev/null
        fi
    done

    # 2. Verifica se o OpenVPN está instalado. Se não, faz a instalação AUTOMÁTICA.
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não detectado. Iniciando instalação automatizada...${SEM_COR}"
        
        # Baixa o instalador se ele não existir
        if [ ! -f "$INSTALLER_PATH" ]; then
            wget -q -O "$INSTALLER_PATH" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
            chmod +x "$INSTALLER_PATH"
        fi

        # Variáveis para instalação não-interativa (Padrões do Angristan)
        export AUTO_INSTALL=y
        sudo -E bash "$INSTALLER_PATH"
        
        echo -e "${VERDE}[OK] OpenVPN instalado com sucesso.${SEM_COR}"
    fi

    # 3. VALIDAÇÃO DE CHAVES (Prevenção do erro static_key_parse_error)
    # Se o serviço existe mas a chave não foi gerada por erro do instalador, geramos manualmente.
    if [ ! -f "/etc/openvpn/server/tc.key" ] && [ ! -f "/etc/openvpn/tls-crypt.key" ] && [ ! -f "/etc/openvpn/tc.key" ]; then
        echo -e "${AMARELO}Gerando chave de segurança TLS ausente...${SEM_COR}"
        openvpn --genkey --secret /etc/openvpn/server/tc.key 2>/dev/null || openvpn --genkey --secret /etc/openvpn/tc.key
    fi

    # 4. Ajuste do Easy-RSA Index
    [ -d "/etc/openvpn/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/easy-rsa"
    [ -d "/etc/openvpn/server/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    
    if [ ! -f "$INDEX_FILE" ]; then
        mkdir -p "$(dirname "$INDEX_FILE")"
        touch "$INDEX_FILE"
    fi

    echo -e "${VERDE}[OK] Sistema validado.${SEM_COR}\n"
    sleep 1
    mover_ovp
}

# --- FUNÇÕES DE GERENCIAMENTO DE USUÁRIOS ---

add_user() {
    IP_EXT=$(curl -4 -s ifconfig.me)
    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
    
    clear
    echo "======================================"
    echo "      GERAR USUÁRIO (PROTEGIDO)       "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT
    [ -z "$CLIENT" ] && return

    echo "Gerando chaves para: $CLIENT..."
    
    # Executa a adição via script oficial
    if yes "" | sudo bash "$INSTALLER_PATH" client add "$CLIENT"; then
        
        # Localiza o arquivo gerado
        ARQUIVO_BRUTO=$(sudo find /root /home -name "${CLIENT}.ovpn" | head -n 1)

        if [ -f "$ARQUIVO_BRUTO" ]; then
            echo "Corrigindo tags de segurança e formatando..."
            TEMP="/tmp/corrigido.ovpn"
            
            # Reconstrói o arquivo para garantir que não haja duplicidade de tags
            sudo bash -c "cat << EOF > $TEMP
client
dev tun
proto udp
remote $IP_EXT 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
ignore-unknown-option block-outside-dns
verb 3
EOF"
            # Extrai CA, CERT e KEY originais
            sudo sed -n '/<ca>/,/<\/key>/p' "$ARQUIVO_BRUTO" >> "$TEMP"

            # INSERÇÃO SEGURA DA TLS-CRYPT (Evita o erro de parse)
            echo "<tls-crypt>" >> "$TEMP"
            if [ -f "/etc/openvpn/server/tc.key" ]; then
                sudo cat "/etc/openvpn/server/tc.key" >> "$TEMP"
            elif [ -f "/etc/openvpn/tc.key" ]; then
                sudo cat "/etc/openvpn/tc.key" >> "$TEMP"
            elif [ -f "/etc/openvpn/server/tls-crypt.key" ]; then
                sudo cat "/etc/openvpn/server/tls-crypt.key" >> "$TEMP"
            else
                # Se não achar no sistema, busca a chave estática dentro do arquivo bruto
                sudo sed -n '/-----BEGIN OpenVPN Static key V1-----/,/-----END OpenVPN Static key V1-----/p' "$ARQUIVO_BRUTO" >> "$TEMP"
            fi
            echo "</tls-crypt>" >> "$TEMP"

            # Finaliza removendo caracteres do Windows e salvando no destino
            sudo tr -d '\r' < "$TEMP" | sudo tee "$ARQUIVO_BRUTO" > /dev/null
            sudo rm "$TEMP"

            echo -e "\n${VERDE}✅ Usuário $CLIENT criado com sucesso!${SEM_COR}"
        else
            echo -e "\n${VERMELHO}❌ Erro: Arquivo .ovpn não gerado pelo instalador.${SEM_COR}"
        fi
    fi
    read -p "Pressione ENTER para continuar..." dummy
    atualiza_ovp
}

# --- FUNÇÕES DE MONITORAMENTO (Resumidas para brevidade, mantenha as suas originais) ---

user_online() {
    clear
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"
    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    if [ ! -f "$STATUS_FILE" ]; then
        echo "Log não encontrado."
    else
        grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | awk -F',' '{print "Usuário: "$2" | IP: "$3" | VPN: "$4}'
    fi
    echo "---------------------------------------------------------------"
    read -p "Pressione ENTER..." dummy
}

# --- FUNÇÕES DE MOVIMENTAÇÃO DE ARQUIVOS ---

mover_ovp() {
    NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
    DESTINO="/home/$NOME_USUARIO/clientes_ovp"
    mkdir -p "$DESTINO"
    chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"

    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)
    if [ -n "$ARQUIVOS" ]; then
        echo "$ARQUIVOS" | while read -r arq; do
            mv "$arq" "$DESTINO/"
            chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO/$(basename "$arq")"
            chmod 644 "$DESTINO/$(basename "$arq")"
        done
    fi
    menu_ovp
}

atualiza_ovp() {
    mover_ovp # Reaproveita a lógica de mover
    user_gerencia
}

# --- MENUS ---

user_gerencia() {
    while true; do
        clear
        echo "======================================"
        echo "      GERENCIAMENTO DE USUÁRIOS       "
        echo "======================================"
        echo "[1] Adicionar Usuário"
        echo "[2] Remover Usuário"
        echo "[3] Listar Todos"
        echo "[4] Voltar"
        read -p "Opção: " OP
        case $OP in
            1) add_user ;;
            2) # Use sua função remove_user original aqui
               echo "Chamando remove_user..." ;;
            3) # Use sua função listar_usuarios original aqui
               echo "Listando..." ;;
            4) return ;;
        esac
    done
}

menu_ovp() {
    while true; do
        clear
        echo "================================================================="
        echo "                       Menu Open VPN                             "
        echo "================================================================="
        echo "[1] Testar velocidade      [4] Gerenciar Usuários"
        echo "[2] Usuários Online        [5] Sair"
        echo "[3] Consumo de Dados"
