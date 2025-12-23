#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"

# Verifica root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# --- FUNÇÕES DE SISTEMA ---

veri_openvpn () {
    echo -e "${AMARELO}Validando ambiente OpenVPN (Versão CLI 2.0)...${SEM_COR}"
    
    # 1. Instala dependências
    apt-get update -qq && apt-get install -y bc vnstat curl wget unzip speedtest-cli net-tools > /dev/null

    # 2. Verifica instalação
    if ! command -v openvpn >/dev/null 2>&1 || [ ! -d "/etc/openvpn/server" ]; then
        echo -e "${AMARELO}[AVISO] OpenVPN não detectado. Iniciando instalação limpa...${SEM_COR}"
        
        if [ ! -f "$INSTALLER_PATH" ]; then
            wget -q -O "$INSTALLER_PATH" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
            chmod +x "$INSTALLER_PATH"
        fi

        # FLAGS CORRIGIDAS PARA CLI 2.0
        # --port 1194 (em vez de --server-port)
        # --protocol (em vez de --server-proto)
        # --dns cloudflare (em vez de número)
        sudo "$INSTALLER_PATH" install \
            --port 1194 \
            --protocol udp \
            --dns cloudflare \
            --client vpn_admin \
            --no-log
        
        sleep 2
    fi

    # 3. Sincronização de Chaves para evitar erro de 'static key parse'
    if [ ! -f "/etc/openvpn/server/tc.key" ]; then
        echo -e "${AMARELO}Sincronizando chaves TLS...${SEM_COR}"
        if [ -f "/etc/openvpn/tls-crypt.key" ]; then
            cp /etc/openvpn/tls-crypt.key /etc/openvpn/server/tc.key
        else
            openvpn --genkey --secret /etc/openvpn/server/tc.key 2>/dev/null
        fi
    fi

    echo -e "${VERDE}[OK] Ambiente pronto.${SEM_COR}\n"
    sleep 1
    mover_ovp
}

# --- GERENCIAMENTO DE USUÁRIOS ---

add_user() {
    IP_EXT=$(curl -4 -s ifconfig.me)
    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
    
    clear
    echo "======================================"
    echo "      GERAR USUÁRIO (VERSÃO CLI)      "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT
    [ -z "$CLIENT" ] && return

    echo "Gerando chaves para: $CLIENT..."
    
    # No Angristan 2.0, o comando 'client add' gera sem senha por padrão se não houver flags extras
    if sudo "$INSTALLER_PATH" client add "$CLIENT"; then
        
        ARQUIVO_BRUTO=$(sudo find /root /home -name "${CLIENT}.ovpn" | head -n 1)

        if [ -f "$ARQUIVO_BRUTO" ]; then
            echo "Formatando arquivo e injetando segurança..."
            TEMP="/tmp/corrigido.ovpn"
            
            # Reconstrói o cabeçalho para garantir compatibilidade
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
            # Extrai CA, CERT e KEY do arquivo original
            sudo sed -n '/<ca>/,/<\/key>/p' "$ARQUIVO_BRUTO" >> "$TEMP"

            # Injeção SEGURA da chave TLS
            echo "<tls-crypt>" >> "$TEMP"
            if [ -f "/etc/openvpn/server/tc.key" ]; then
                sudo cat "/etc/openvpn/server/tc.key" >> "$TEMP"
            elif [ -f "/etc/openvpn/tc.key" ]; then
                sudo cat "/etc/openvpn/
