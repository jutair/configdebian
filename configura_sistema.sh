#!/bin/bash
# configura_sistema.sh

DESTINO="/opt/configdebian"

apt-get update && apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc

for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
        fi
    fi

    # LIMPEZA E CONFIGURAÇÃO DO LOGIN
    # Removemos qualquer lixo de versões antigas
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc

    # ÚNICA LINHA QUE DEVE IR PARA O LOGIN:
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# Permissões globais (Executadas agora pelo script, não no login)
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

echo "Configuração completa em $DESTINO"
