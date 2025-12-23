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
        echo -e "${AMARELO}[AVISO] OpenVPN não detectado. Instalando...${SEM_COR}"
        
        if [ ! -f "$INSTALLER_PATH" ]; then
            wget -q -O "$INSTALLER_PATH" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
            chmod +x "$INSTALLER_PATH"
        fi

        # COMANDO SIMPLIFICADO (SEM --no-log E SEM QUEBRAS DE LINHA)
        sudo "$INSTALLER_PATH" install --port 1194 --protocol udp --dns cloudflare --client vpn_admin
        
        sleep 2
    fi

    # 3. Sincronização de Chaves TLS
    if [ ! -f "/etc/openvpn/server/tc.key" ]; then
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
    
    if sudo "$INSTALLER_PATH" client add "$CLIENT"; then
        ARQUIVO_BRUTO=$(sudo find /root /home -name "${CLIENT}.ovpn" | head -n 1)

        if [ -f "$ARQUIVO_BRUTO" ]; then
            echo "Formatando arquivo e injetando segurança..."
            TEMP="/tmp/corrigido.ovpn"
            
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
            sudo sed -n '/<ca>/,/<\/key>/p' "$ARQUIVO_BRUTO" >> "$TEMP"

            echo "<tls-crypt>" >> "$TEMP"
            if [ -f "/etc/openvpn/server/tc.key" ]; then
                sudo cat "/etc/openvpn/server/tc.key" >> "$TEMP"
            elif [ -f "/etc/openvpn/tc.key" ]; then
                sudo cat "/etc/openvpn/tc.key" >> "$TEMP"
            else
                sudo sed -n '/-----BEGIN OpenVPN Static key V1-----/,/-----END OpenVPN Static key V1-----/p' "$ARQUIVO_BRUTO" >> "$TEMP"
            fi
            echo "</tls-crypt>" >> "$TEMP"

            sudo tr -d '\r' < "$TEMP" | sudo tee "$ARQUIVO_BRUTO" > /dev/null
            sudo rm "$TEMP"
            echo -e "\n${VERDE}✅ Usuário $CLIENT criado com sucesso!${SEM_COR}"
        else
            echo -e "\n${VERMELHO}❌ Erro: Arquivo não localizado.${SEM_COR}"
        fi
    fi
    read -p "Pressione ENTER para continuar..." dummy
    atualiza_ovp
}

remove_user() {
    clear
    echo "======================================"
    echo "       REMOVER USUÁRIO (CLI)          "
    echo "======================================"
    read -p "Digite o nome para remover: " CLIENT
    [ -z "$CLIENT" ] && return

    if sudo "$INSTALLER_PATH" client revoke "$CLIENT"; then
        sudo rm -f "/root/$CLIENT.ovpn"
        sudo rm -f "/home/$USER_ATUAL/clientes_ovp/$CLIENT.ovpn"
        echo -e "\n${VERDE}✅ Usuário $CLIENT removido.${SEM_COR}"
    else
        echo -e "\n${VERMELHO}❌ Erro ao remover usuário.${SEM_COR}"
    fi
    read -p "Pressione ENTER..." dummy
    atualiza_ovp
}

# --- ORGANIZAÇÃO E MENUS ---

mover_ovp() {
    NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
    DESTINO="/home/$NOME_USUARIO/clientes_ovp"
    mkdir -p "$DESTINO"
    
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
    mover_ovp
    user_gerencia
}

user_gerencia() {
    while true; do
        clear
        echo "======================================"
        echo "      GERENCIAMENTO DE USUÁRIOS       "
        echo "======================================"
        echo "[1] Adicionar Usuário"
        echo "[2] Remover Usuário"
        echo "[3] Voltar"
        read -p "Opção: " OP
        case $OP in
            1) add_user ;;
            2) remove_user ;;
            3) return ;;
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
        echo "================================================================="
        read -n 1 -p "Opção: " OPCAO
        echo ""
        case $OPCAO in
            1) clear; speedtest-cli --simple; read -p "ENTER..." dummy ;;
            2) clear; echo "--- Usuários Online ---"; 
               grep "CLIENT_LIST" /etc/openvpn/server/openvpn-status.log 2>/dev/null || echo "Log não disponível"; 
               read -p "ENTER..." dummy ;;
            4) user_gerencia ;;
            5) cd "/home/$USER_ATUAL/configdebian-main/" && exec sudo -E bash ./menu.sh ;;
            *) echo "Inválido"; sleep 1 ;;
        esac
    done
}

# Início
veri_openvpn
