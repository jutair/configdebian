#!/bin/bash
# configura_sistema.sh - Versão Slim (Sem erros de cópia)

DESTINO="/opt/configdebian"

# 1. Instalação de pacotes (Vnstat, ufw, etc)
apt-get update && apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Estrutura de pastas
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Copia Chave SSH do root para o usuário (Evita 'Permission Denied')
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/ 2>/dev/null
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys
        fi
    fi

    # --- O SEGREDO DO LOGIN LIMPO ---
    # Limpa o bashrc de comandos antigos e adiciona apenas o necessário
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc      # Remove qualquer 'cp' que tenha ficado
    sed -i '/chmod /d' /home/$USERNAME/.bashrc   # Remove qualquer 'chmod' que tenha ficado
    
    # Adiciona apenas a chamada do menu
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões Globais (Sem o erro de 'No such file')
if [ -d "$DESTINO" ]; then
    chown -R root:sudo "$DESTINO"
    chmod -R 775 "$DESTINO"
    chmod +x "$DESTINO"/*.sh
fi

echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
