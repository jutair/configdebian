#!/bin/bash
# configura_sistema.sh - Versão Slim (Focada em Usuários)

DESTINO="/opt/configdebian"

# 1. Instalação (Vnstat, etc)
apt-get update && apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Copia chaves SSH para não dar "Public Key Denied"
        mkdir -p /home/$USERNAME/.ssh
        [ -f /root/.ssh/authorized_keys ] && cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
        chown -R $USERNAME:$USERNAME /home/$USERNAME
        chmod 700 /home/$USERNAME/.ssh
    fi

    # Configura o Bashrc para abrir o menu do local correto (/opt)
    # IMPORTANTE: Use o caminho completo
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    echo "sudo -E bash /opt/configdebian/menu.sh" >> /home/$USERNAME/.bashrc
done

# 3. Permissões Globais
chown -R root:sudo "$DESTINO"
chmod -R 755 "$DESTINO"
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
