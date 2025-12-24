#!/bin/bash
# configura_sistema.sh - Configura sistema, usuários e scripts configdebian
# Atualizado: 24-12-2025

set -e

USERS=("jutair" "guest")
DIR_CONFIG="/opt/configdebian"
GITHUB_REPO="https://raw.githubusercontent.com/jutair/configdebian/main"
OPENVPN_SCRIPT="openvpn-install.sh"
SCRIPTS=("menu.sh" "open_vpn_conf.sh" "gerencia_rede.sh" "usuarios.sh" "update_sistema.sh" "backup.sh" "configura_sistema.sh")

# --- Verifica ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

echo "🔧 Atualizando sistema e instalando pacotes essenciais..."
apt-get update
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo curl wget unzip

# --- Cria pasta global configdebian ---
mkdir -p "$DIR_CONFIG"
chown root:sudo "$DIR_CONFIG"
chmod 775 "$DIR_CONFIG"

# --- Baixa scripts principais do GitHub ---
echo "⏳ Baixando scripts configdebian..."
for SCRIPT in "${SCRIPTS[@]}"; do
    URL="$GITHUB_REPO/$SCRIPT"
    DEST="$DIR_CONFIG/$SCRIPT"
    curl -fsSL "$URL" -o "$DEST" || echo "⚠ Falha ao baixar $SCRIPT"
    chmod +x "$DEST"
    chown root:sudo "$DEST"
done

# --- Baixa openvpn-install.sh oficial ---
curl -fsSL "https://raw.githubusercontent.com/angristan/openvpn-install/master/$OPENVPN_SCRIPT" -o "$DIR_CONFIG/$OPENVPN_SCRIPT"
chmod +x "$DIR_CONFIG/$OPENVPN_SCRIPT"
chown root:sudo "$DIR_CONFIG/$OPENVPN_SCRIPT"

# --- Criação de usuários e configuração automática ---
for USERNAME in "${USERS[@]}"; do
    USER_HOME="/home/$USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        echo "👤 Criando usuário $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
    fi

    mkdir -p "$USER_HOME"/{Backup,clientes_ovp,transfer}
    chown -R "$USERNAME:$USERNAME" "$USER_HOME"

    # Copia chave SSH do root
    if [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p "$USER_HOME/.ssh"
        cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
        chmod 700 "$USER_HOME/.ssh"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
    fi

    # Configura .bashrc para iniciar menu automaticamente
    cat <<'EOF' > "$USER_HOME/.bashrc"
[[ $- != *i* ]] && return
if [ -z "$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash /opt/configdebian/menu.sh
fi
EOF

    # Configura .profile para carregar .bashrc
    cat <<'EOF' > "$USER_HOME/.profile"
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

    chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
    chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"
done

# --- Permite sudo sem senha ---
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# --- Permissões da pasta global ---
chmod -R 775 "$DIR_CONFIG"
chmod +x "$DIR_CONFIG"/*.sh
chown -R root:sudo "$DIR_CONFIG"

echo "✅ Configuração completa. Usuários jutair e guest logarão diretamente no menu."

# ===============================================================
# BLOCO DE SEGURANÇA E PROTEÇÃO DE RECURSOS
# ===============================================================

echo -e "${AZUL}Configurando blindagem do sistema...${NC}"

# 1. Proteção contra Fork Bomb e Abuso de RAM (Limits)
# Define limites para usuários que não sejam root
cat <<EOF > /etc/security/limits.d/vps_protecao.conf
* soft    nproc           100
* hard    nproc           150
* soft    as              1048576
* hard    as              2097152
* soft    fsize           50000
* hard    fsize           100000
EOF

# 2. Blindagem do Kernel (Sysctl)
# Protege contra ataques de rede (SYN Flood) e tentativas de exploit
cat <<EOF > /etc/sysctl.d/99-vps-security.conf
# Proteção contra ataques SYN Flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Ignorar respostas de ICMP (Evita Ping Flood e descoberta de rede)
net.ipv4.icmp_echo_ignore_all = 1

# Proteção contra IP Spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desabilitar redirecionamento de pacotes (Segurança de roteamento)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Proteção contra estouro de memória (OOM-Killer ajustado)
vm.swappiness = 10
vm.overcommit_memory = 1
EOF

# Aplicar as mudanças de Kernel imediatamente
sysctl -p /etc/sysctl.d/99-vps-security.conf

# 3. Proteção Automática Anti-Brute Force (SSH)
# Garante que o UFW esteja logando para o seu Dashboard mostrar os bloqueios
ufw logging medium
ufw limit ssh

echo -e "${VERDE}Blindagem aplicada com sucesso!${NC}"
echo "✅ Configuração completa. Usuários jutair e guest logarão diretamente no menu."
echo "De um comando exit e logue novamente com o usuário jutair ou guest"
