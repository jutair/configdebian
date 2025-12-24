#!/bin/bash
# configura_sistema.sh

DESTINO="/opt/configdebian"

# Instalação de pacotes
apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc

# Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Copia Chave SSH do root para o usuário
        mkdir -p /home/$USERNAME/.ssh
        [ -f /root/.ssh/authorized_keys ] && cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
        chown -R $USERNAME:$USERNAME /home/$USERNAME
    fi

    # Injeção do Menu (Caminho absoluto corrigido)
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
done

# Permissão para o Sudo não pedir senha no menu
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

# Garante que o diretório global esteja correto ao final
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
