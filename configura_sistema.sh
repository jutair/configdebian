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
        
        # Copia a chave SSH do root para o usuário conseguir logar direto
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys 2>/dev/null
        fi
    fi

    # --- LIMPEZA CRÍTICA DO BASHRC ---
    # Remove qualquer linha de 'cp', 'chmod' ou chamadas antigas que causam erro no login
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/Configuração completa/d' /home/$USERNAME/.bashrc

    # INJETA APENAS A CHAMADA DO MENU (Sem erros de permissão)
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    # Garante que o dono da home é o próprio usuário
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissão para o Sudo não pedir senha no menu
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

# 4. Permissões na pasta global para o grupo sudo (onde jutair está)
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"

echo "Configuração finalizada com sucesso em $DESTINO"
