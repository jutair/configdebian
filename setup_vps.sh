#!/bin/bash
# setup_vps.sh - Instalador de Segurança e Gestão VPS
# Atualizado: 27-12-2025

# --- CORES ---
VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; VERDE='\033[0;32m'; AZUL='\033[0;34m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este script precisa de privilégios de ROOT.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

set -e

# --- CONFIGURAÇÕES ---
DIR_CONFIG="/opt/configdebian"
DIR_PROT="/etc/vps_protecao"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "setup_vps.sh" "guardiao.sh" "login.sh")

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "           ${VERDE}INSTALADOR DE SEGURANÇA E GESTÃO VPS${NC}"
echo -e "                SISTEMA CONFIGDEBIAN 2025${NC}"
echo -e "${AZUL}===============================================================${NC}"

# --- 1. COLETA DE DADOS ---
echo -e "${AMARELO}👤 Cadastro de Usuários do Sistema:${NC}"
read -p " Nome para o ADMINISTRADOR: " ADM_USER
read -s -p " Senha para o administrador $ADM_USER: " ADM_PASS
echo -e "\n"
read -p " Nome para o OPERADOR: " OPE_USER
read -s -p " Senha para o operador $OPE_USER: " OPE_PASS
echo -e "\n${AZUL}---------------------------------------------------------------${NC}"

# --- 2. PERGUNTA DE CONFIGURAÇÃO IMEDIATA ---
echo -e "${AMARELO}📢 Configuração de Alertas Telegram:${NC}"
echo -e "Deseja configurar o Bot do Telegram agora?"
echo -e " [1] Sim, configurar agora"
echo -e " [2] Não, configurar depois (pelo Menu de Rede)"
read -n 1 -p " Escolha: " OP_TELE; echo ""

if [[ "$OP_TELE" == "1" ]]; then
    read -p " Token do Bot: " TOKEN
    read -p " ID do Chat: " ID_CHAT
else
    TOKEN="NAO_DEFINIDO"
    ID_CHAT="NAO_DEFINIDO"
fi
echo -e "${AZUL}---------------------------------------------------------------${NC}"

# --- 3. CRIAÇÃO DAS PASTAS E ARQUIVOS ---
mkdir -p "$DIR_PROT"
mkdir -p "$DIR_CONFIG"

echo "ADM_USER=\"$ADM_USER\"" > "$DIR_PROT/admin.conf"
echo "OPE_USER=\"$OPE_USER\"" >> "$DIR_PROT/admin.conf"
echo "TOKEN=\"$TOKEN\"" > "$DIR_PROT/telegram.conf"
echo "ID_CHAT=\"$ID_CHAT\"" >> "$DIR_PROT/telegram.conf"

chmod 700 "$DIR_PROT"
chmod 600 "$DIR_PROT/admin.conf"
chmod 600 "$DIR_PROT/telegram.conf"

# --- 4. INSTALAÇÃO DE PACOTES ---
echo -e "${AMARELO}🔧 Instalando pacotes necessários...${NC}"
apt-get update -y && apt-get install -y vnstat ufw fail2ban openvpn sudo curl wget bc jq unzip procps speedtest-cli dnsmasq

# Define o fuso horário para Manaus
timedatectl set-timezone America/Manaus
timedatectl set-ntp true

# Inicia o vnstat
systemctl enable vnstat
systemctl start vnstat

# --- 5. DOWNLOAD DOS SCRIPTS ---
echo -e "${AMARELO}⏳ Sincronizando ferramentas do GitHub...${NC}"
for SCRIPT in "${SCRIPTS[@]}"; do
    URL_DOWNLOAD="$GITHUB_REPO/$SCRIPT"
    curl -fsSL "$URL_DOWNLOAD" -o "$DIR_CONFIG/$SCRIPT" || echo -e "${VERMELHO}⚠ Erro ao baixar $SCRIPT${NC}"
    chmod +x "$DIR_CONFIG/$SCRIPT"
done

# --- 6. CRIAÇÃO DE USUÁRIOS NO LINUX ---
echo -e "${AMARELO}👤 Configurando contas de acesso...${NC}"
for USUARIO in "$ADM_USER" "$OPE_USER"; do
    if ! id "$USUARIO" &>/dev/null; then
        useradd -m -s /bin/bash "$USUARIO"
        [ "$USUARIO" == "$ADM_USER" ] && SENHA="$ADM_PASS" || SENHA="$OPE_PASS"
        echo "$USUARIO:$SENHA" | chpasswd
    fi
done
usermod -aG sudo "$ADM_USER"
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# --- 7. BLINDAGEM E LIBERAÇÃO DE ACESSO ---
echo -e "${AMARELO}🛡️ Aplicando travas e liberando SSH por senha...${NC}"
SSH_CONF="/etc/ssh/sshd_config"
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONF
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONF
sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' $SSH_CONF
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONF

# Configura execução do login.sh no SSH
sed -i '/login.sh/d' /etc/pam.d/sshd
echo "session optional pam_exec.so $DIR_CONFIG/login.sh" >> /etc/pam.d/sshd

# Configura o menu automático
sed -i '/menu.sh/d' /etc/profile
echo "[ -f $DIR_CONFIG/menu.sh ] && exec bash $DIR_CONFIG/menu.sh" >> /etc/profile

systemctl restart ssh

# --- 8. Proteção contra Fork Bomb e Limite de Processos ---
echo -e "${AMARELO}🛡️ Configurando limites de processos (Anti-ForkBomb)...${NC}"
cat <<'EOF' > /etc/security/limits.d/99-vpn-limits.conf
* soft    nproc           100
* hard    nproc           150
* soft    nofile          1024
* hard    nofile          2048
root            soft    nproc           unlimited
root            hard    nproc           unlimited
EOF
echo "$ADM_USER       soft    nproc           unlimited" >> /etc/security/limits.d/99-vpn-limits.conf
echo "$ADM_USER       hard    nproc           unlimited" >> /etc/security/limits.d/99-vpn-limits.conf
if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

# --- 9. Adicionado tun0 ao monitoramento do vnstat ---
if ip link show tun0 > /dev/null 2>&1; then
    vnstat -i tun0 --add
    systemctl restart vnstat
fi

# --- 10. Inicialização do guardião ---
echo -e "${AMARELO}🚀 Ativando Guardião...${NC}"
pkill -f "guardiao.sh" > /dev/null 2>&1 || true
nohup /bin/bash "$DIR_CONFIG/guardiao.sh" > /dev/null 2>&1 &

# --- 11. Função de configuração do servidor VPN ---
configurar_servidor_vpn() {
    clear
    [ -f "$DIR_PROT/admin.conf" ] && source "$DIR_PROT/admin.conf"

    local USUARIO_ATUAL=$(logname 2>/dev/null || whoami)
    local DATA_ATUAL=$(date +'%d/%m/%Y')
    local HORA_ATUAL=$(date +'%H:%M:%S')

    if [[ "$USUARIO_ATUAL" != "$ADM_USER" ]]; then
        echo -e "${VERMELHO}⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️${NC}"
        if [ -f "$DIR_PROT/telegram.conf" ]; then
            source "$DIR_PROT/telegram.conf"
            MENSAGEM="🚨 <b>TENTATIVA DE ALTERAR O SERVIDOR VPN!</b>%0A<b>Usuário:</b> <code>$USUARIO_ATUAL</code>%0A<b>Data/Hora:</b> $DATA_ATUAL às $HORA_ATUAL"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                 -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3
        return
    fi

    echo -e "${AZUL}CONFIGURAÇÃO DO SERVIDOR OPENVPN${NC}"

    # --- Diretórios ---
    sudo mkdir -p "$DIR_PROT/clientes" "$DIR_PROT/consumo_clientes" "$DIR_PROT/{categorias,perfis,clientes}"
    sudo chmod 755 "$DIR_PROT" "$DIR_PROT/clientes" "$DIR_PROT/consumo_clientes"

    # --- DNSMASQ base ---
    cat > /etc/dnsmasq.d/vpn.conf <<'EOF'
# DNS upstream confiáveis
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
    systemctl restart dnsmasq || echo -e "${AMARELO}⚠️ dnsmasq inicializado parcialmente. tun0 ainda não existe.${NC}"

    # --- Função para ativar DNS da VPN sem derrubar conexões ---
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
    mkdir -p "$DIR_PROT/categorias" "$DIR_PROT/perfis" "$DIR_PROT/clientes"
    [ ! -f "$DIR_PROT/categorias/adultos.list" ] && cat > "$DIR_PROT/categorias/adultos.list" <<EOF
pornhub.com
xvideos.com
xnxx.com
youporn.com
redtube.com
EOF
    [ ! -f "$DIR_PROT/categorias/bancos.list" ] && cat > "$DIR_PROT/categorias/bancos.list" <<EOF
bb.com.br
itau.com.br
bradesco.com.br
santander.com.br
nubank.com.br
caixa.gov.br
inter.co
EOF
    [ ! -f "$DIR_PROT/perfis/criancas.conf" ] && echo "adultos" > "$DIR_PROT/perfis/criancas.conf"
    [ ! -f "$DIR_PROT/perfis/idosos.conf" ] && echo "bancos" > "$DIR_PROT/perfis/idosos.conf"
    [ ! -f "$DIR_PROT/perfis/livre.conf" ] && : > "$DIR_PROT/perfis/livre.conf"

    # --- Ativa DNS da VPN de forma segura ---
    ativar_dns_vpn

    echo -e "${VERDE}✅ Configuração do servidor VPN e categorias finalizada.${NC}"
}

echo -e "${AZUL}===============================================================${NC}"
echo -e "    ${VERDE}✅ SISTEMA INSTALADO E LIBERADO!${NC}"
echo -e "    Administrador: ${AMARELO}$ADM_USER${NC}"
echo -e "    ${VERDE}Acesso SSH por senha: ATIVADO${NC}"
echo -e "${AZUL}===============================================================${NC}"
