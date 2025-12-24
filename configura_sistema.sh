#!/bin/bash
# configura_sistema.sh - O CONFIGURADOR (VERSÃO LIMPEZA TOTAL) - Correção 24/12/2025-v2

DESTINO="/opt/configdebian"

# 1. Instalação de pacotes (Essencial para as funções do menu)
apt-get update && apt-get install -y vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}

        # COPIA A CHAVE SSH (Para evitar o erro 'Permission denied')
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys 2>/dev/null
        fi
    fi

    # --- BLOCO DE LIMPEZA AGRESSIVA (Remove os erros do login) ---
    # Remove qualquer linha que contenha esses termos problemáticos
    sed -i '/configdebian/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/Configuração completa/d' /home/$USERNAME/.bashrc
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc

    # Adiciona a única linha correta para chamar o menu
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    # Garante que o usuário é dono da sua home e do .bashrc limpo
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões de Sudo (Para o menu rodar sem pedir senha)
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 4. Ajuste final de permissões na pasta global /opt
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo "Configuração finalizada com sucesso!"
