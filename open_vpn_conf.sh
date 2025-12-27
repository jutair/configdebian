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

    # --- DNSMASQ base (interface será ativada quando a VPN existir) ---
    cat > /etc/dnsmasq.d/vpn.conf <<'EOF'
# ================================
# DNSMASQ - OPENVPN ONLY
# ================================
# DNS upstream confiáveis
no-resolv
server=1.1.1.1
server=8.8.8.8

# Cache
cache-size=5000

# Segurança
domain-needed
bogus-priv
stop-dns-rebind
rebind-localhost-ok

# Log
log-queries
log-facility=/var/log/dnsmasq.log
EOF

    touch /var/log/dnsmasq.log
    chmod 644 /var/log/dnsmasq.log
    systemctl enable dnsmasq
    systemctl restart dnsmasq || echo -e "${AMARELO}⚠️ dnsmasq inicializado parcialmente. tun0 ainda não existe.${NC}"

    # Função para ativar DNS da VPN sem derrubar conexões
    ativar_dns_vpn() {
        if ip link show tun0 > /dev/null 2>&1; then
            if ! grep -q '^interface=tun0' /etc/dnsmasq.d/vpn.conf; then
                sed -i '1iinterface=tun0\nbind-interfaces\nlisten-address=10.8.0.1' /etc/dnsmasq.d/vpn.conf
                systemctl restart dnsmasq
                echo -e "${VERDE}✅ DNS da VPN ativado para tun0.${NC}"
            else
                echo -e "${AZUL}🔹 DNS da VPN já configurado para tun0.${NC}"
            fi
        else
            echo -e "${AMARELO}⚠️ tun0 ainda não existe. DNS da VPN será ativado quando a primeira VPN for criada.${NC}"
        fi
    }

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

    # --- Ativa DNS da VPN de forma segura ---
    ativar_dns_vpn

    echo -e "${VERDE}✅ Configuração do servidor VPN e categorias finalizada.${NC}"
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

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERENCIAMENTO OPENVPN PRO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [2] 🗑️  Remover Usuário                [6] 📂 Listar Downloads (SCP)"
    echo -e "  [1] 👤 Criar Usuário                  [7] 📤 Enviar Telegram (Manual)"
    echo -e "  [3] 📋 Listar Cadastros               [8] 📊 Gerenciamento de Banda"
    echo -e "  [4] 🟢 Ver Usuários Online            [9] Bloquear Serviços da VPN"
    echo -e "  [5] ⚙️  Configurar Servidor           [0] ⬅️ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha uma opção: " OP; echo ""
    case $OP in
        1) criar_usuario ;;
        2) remover_usuario ;;
        3) listar_arquivos_ovpn ;;
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
