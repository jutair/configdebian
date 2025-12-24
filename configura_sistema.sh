#!/bin/bash
# configura_sistema.sh - O CONFIGURADOR (RODA DENTRO DE /OPT)

DESTINO="/opt/configdebian"

# 1. Instala os pacotes do sistema
apt-get update && apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configura os Usuários (jutair e guest)
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Copia a chave SSH para permitir login direto
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
        fi
    fi

    # --- LIMPEZA DO BASHRC (PARA NÃO TER MENSAGENS DE ERRO) ---
    # Removemos qualquer lixo de tentativas anteriores
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/Configuração completa/d' /home/$USERNAME/.bashrc

    # ADICIONA APENAS A ENTRADA DO MENU
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões de Sudo (Para o menu não pedir senha)
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

# 4. Ajuste final de permissões na pasta global
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"

echo "Instalação concluída com sucesso!"
