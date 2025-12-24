#!/bin/bash
# configura_sistema.sh - O CONFIGURADOR (SILENCIOSO)

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
        
        # Copia a chave SSH para login direto
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys 2>/dev/null
        fi
    fi

    # --- LIMPEZA E INJEÇÃO DO MENU ---
    # Remove lixo de tentativas anteriores no .bashrc
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/Configuração completa/d' /home/$USERNAME/.bashrc

    # Adiciona apenas a chamada do menu
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões de Sudo (Sem pedir senha)
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

# 4. Ajuste final de permissões na pasta global
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"

echo "Instalação concluída com sucesso em $DESTINO!"
