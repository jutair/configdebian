#!/bin/bash
# configura_sistema.sh - O CONFIGURADOR (COM CORREÇÃO DE SSH) 24-12-2025-v1

DESTINO="/opt/configdebian"

# 1. Instalação de pacotes
apt-get update && apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}

        # BLOCO ESSENCIAL: Copia sua chave para você conseguir logar
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys 2>/dev/null
        fi
    fi

    # --- LIMPEZA E INJEÇÃO DO MENU ---
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/configdebian/d' /home/$USERNAME/.bashrc
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões de Sudo
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 4. Ajuste final
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo "Instalação concluída com sucesso!"
