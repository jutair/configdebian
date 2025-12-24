#!/bin/bash
# configura_sistema.sh - Versão Final (Correção de Permissões e Login)

# 1. Mover os scripts para um local acessível (fora da pasta root)
DESTINO="/opt/configdebian"
rm -rf "$DESTINO"
mkdir -p "$DESTINO"
cp -r $HOME/configdebian-main/* "$DESTINO/"

# 2. Instalação de pacotes
apt-get update && apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 3. Configuração VnStat
systemctl start vnstat
systemctl enable vnstat

# 4. CRIAÇÃO DE USUÁRIOS (jutair e guest)
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Estrutura de pastas na home do utilizador
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # --- CORREÇÃO DO SSH ---
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys
        fi

        # --- CORREÇÃO DO MENU NO LOGIN ---
        # Usamos o caminho absoluto /opt/configdebian para evitar erros de permissão
        sed -i '/menu.sh/d' /home/$USERNAME/.bashrc # Limpa entradas duplicadas
        echo "if [ -f $DESTINO/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
        
        chown -R $USERNAME:$USERNAME /home/$USERNAME
    fi
done

# 5. Permissões Globais
chmod -R 755 "$DESTINO"
chmod +x "$DESTINO"/*.sh
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

echo "Configuração concluída com sucesso!"
