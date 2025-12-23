add_user() {
    # 1. Configurações iniciais e IP
    IP_EXT=$(curl -4 -s ifconfig.me)
    [ -z "$IP_EXT" ] && { echo -e "${VERMELHO}Erro ao obter IP externo${SEM_COR}"; return 1; }

    # 2. Sincroniza Chave Mestra para evitar TLS Error
    CHAVE_MESTRA="/etc/openvpn/server/tls-crypt.key"
    if [ ! -f "$CHAVE_MESTRA" ]; then
        sudo cp /etc/openvpn/tls-crypt.key "$CHAVE_MESTRA" 2>/dev/null
    fi

    # 3. Garante o Template limpo (Sem espaços na margem esquerda)
sudo bash -c "cat << EOF > /etc/openvpn/server/client-template.txt
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
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
verb 3
EOF"

    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
    INSTALLER="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
    
    clear
    echo "======================================"
    echo "      ADICIONAR NOVO USUÁRIO          "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT
    [ -z "$CLIENT" ] && return

    # 4. Limpeza preventiva no banco do Easy-RSA
    if sudo ls /etc/openvpn/server/easy-rsa/pki/issued/ 2>/dev/null | grep -q "${CLIENT}.crt"; then
        echo -e "${AMARELO}Limpando registro antigo de $CLIENT...${SEM_COR}"
        sudo bash "$INSTALLER" client revoke "$CLIENT" > /dev/null 2>&1
    fi

    echo -e "${AMARELO}Gerando certificado...${SEM_COR}"
    cd /tmp
    if sudo bash "$INSTALLER" client add "$CLIENT" > /dev/null 2>&1; then
        ARQUIVO_GERADO=$(sudo find /root /home -name "${CLIENT}.ovpn" | head -n 1)

        if [ -n "$ARQUIVO_GERADO" ] && [ -f "$ARQUIVO_GERADO" ]; then
            echo "Otimizando sintaxe do arquivo..."

            # --- TRATAMENTO ANTI-CORRUPÇÃO (Fix Buffer_Full) ---
            
            # A. Remove lixo descritivo dentro da tag <cert>
            sudo sed -i '/<cert>/,/-----BEGIN CERTIFICATE-----/{/<cert>/b; /-----BEGIN CERTIFICATE-----/b; d}' "$ARQUIVO_GERADO"
            
            # B. Remove linhas em branco (Culpado principal do buffer_full)
            sudo sed -i '/^$/d' "$ARQUIVO_GERADO"

            # C.
