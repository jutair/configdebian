#!/bin/bash

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_OVPN="/etc/openvpn/server"
DIR_CLIENTES="/root/usuarios_vpn"
ADMIN_CONF="/etc/vps_protecao/admin.conf"
TELEGRAM_CONF="/etc/vps_protecao/telegram.conf"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# Cria o diretório de backup dos arquivos .ovpn se não existir
mkdir -p "$DIR_CLIENTES"

# --- FUNÇÃO: ENVIAR TELEGRAM ---
enviar_telegram() {
    local ARQUIVO=$1
    local NOME_USER=$2
    
    if [ -f "$TELEGRAM_CONF" ]; then
        source "$TELEGRAM_CONF"
        if [[ -n "$TOKEN" && -f "$ARQUIVO" ]]; then
            # Mensagem de texto formatada
            MENSAGEM="✅ <b>NOVO USUÁRIO VPN GERADO</b>%0A👤 Nome: <code>$NOME_USER</code>%0A📅 Data: $(date +'%d/%m/%Y')%0A⏰ Hora: $(date +'%H:%M:%S')"
            
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                -d chat_id="$ID_CHAT" \
                -d text="$MENSAGEM" \
                -d parse_mode="HTML" > /dev/null
            
            # Envio do arquivo .ovpn
            curl -s -F chat_id="$ID_CHAT" \
                -F document=@"$ARQUIVO" \
                "https://api.telegram.org/bot$TOKEN/sendDocument" > /dev/null
        fi
    fi
}

# --- FUNÇÃO: CONFIGURAR SERVIDOR ---
configurar_servidor_vpn() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "              ${VERDE}CONFIGURAÇÃO DO SERVIDOR OPENVPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"

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
        echo -e "  [1] Adicionar/Remover/Modificar via Script Oficial"
        echo -e "  [2] Reinstalar/Atualizar Script de Instalação"
        echo -e "  [0] Voltar"
        read -n 1 -p " Escolha: " OP_SVR
        case $OP_SVR in
            1) bash /root/openvpn-install.sh ;;
            2) wget https://git.io/vpn -O /root/openvpn-install.sh && chmod +x /root/openvpn-install.sh && echo -e "\n${VERDE}Atualizado!${NC}" && sleep 2 ;;
        esac
    fi
}

# --- FUNÇÃO: LISTAR USUÁRIOS ---
listar_usuarios() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}USUÁRIOS VPN ATIVOS (CERTIFICADOS)${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Busca na pasta do Easy-RSA
    ISSUED_DIR="/etc/openvpn/server/easy-rsa/pki/issued"
    [ ! -d "$ISSUED_DIR" ] && ISSUED_DIR="/etc/openvpn/easy-rsa/pki/issued"

    if [ -d "$ISSUED_DIR" ]; then
        ls "$ISSUED_DIR" | grep ".crt" | sed 's/.crt//' | grep -v "server" | while read -r user; do
            echo -e " 👤 Usuário: ${AMARELO}$user${NC}"
        done
    else
        echo -e "${VERMELHO}Erro: Pasta de certificados não localizada.${NC}"
    fi
    
    echo -e "${AZUL}===============================================================${NC}"
    read -p "Pressione ENTER para voltar..."
}

# --- FUNÇÃO: CRIAR USUÁRIO ---
criar_usuario() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                  ${VERDE}CRIAR NOVO USUÁRIO VPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário: " NOVO_USER
    
    if [[ -z "$NOVO_USER" ]]; then
        echo -e "${VERMELHO}Nome vazio!${NC}"; sleep 2; return
    fi

    if [ -f "/root/openvpn-install.sh" ]; then
        # Automação das respostas para o script oficial
        export MENU_OPTION=1
        export CLIENT="$NOVO_USER"
        export PASS=1
        bash /root/openvpn-install.sh
        
        # Localiza o arquivo gerado
        ARQUIVO_ORIGEM="/root/$NOVO_USER.ovpn"
        [ ! -f "$ARQUIVO_ORIGEM" ] && ARQUIVO_ORIGEM="$HOME/$NOVO_USER.ovpn"

        if [ -f "$ARQUIVO_ORIGEM" ]; then
            mv "$ARQUIVO_ORIGEM" "$DIR_CLIENTES/"
            echo -e "${VERDE}Usuário criado com sucesso!${NC}"
            echo -e "Enviando para o Telegram..."
            enviar_telegram "$DIR_CLIENTES/$NOVO_USER.ovpn" "$NOVO_USER"
        fi
    else
        echo -e "${VERMELHO}Instalador /root/openvpn-install.sh não encontrado.${NC}"
    fi
    sleep 3
}

# --- FUNÇÃO: REMOVER USUÁRIO ---
remover_usuario() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                  ${VERMELHO}REMOVER USUÁRIO VPN${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    read -p " Nome do usuário para remover: " USER_DEL

    if [ -f "/root/openvpn-install.sh" ]; then
        export MENU_OPTION=2
        export CLIENT="$USER_DEL"
        bash /root/openvpn-install.sh
        rm -f "$DIR_CLIENTES/$USER_DEL.ovpn"
        echo -e "${AMARELO}Usuário $USER_DEL removido e arquivo deletado.${NC}"
    else
        echo -e "${VERMELHO}Instalador não encontrado.${NC}"
    fi
    sleep 3
}

# --- MENU PRINCIPAL UNIFICADO ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAMENTO OPENVPN PRO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 👤 Criar Usuário (Envia Telegram)"
    echo -e "  [2] 🗑️  Remover Usuário"
    echo -e "  [3] 📋 Listar Usuários Ativos"
    echo -e "  [4] ⚙️  Configurar/Instalar Servidor"
    echo -e "  [0] ⬅️  Voltar ao Painel Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OP
    echo ""

    case $OP in
        1) criar_usuario ;;
        2) remover_usuario ;;
        3) listar_usuarios ;;
        4) configurar_servidor_vpn ;;
        0) exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
