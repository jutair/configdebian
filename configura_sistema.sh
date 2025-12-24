#!/bin/bash
# configura_sistema.sh - Construtor

DIR_SCRIPTS="$HOME/configdebian-main"

# 1. Instalação de pacotes (Removido -u do vnstat para compatibilidade)
apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. Configuração VnStat (Debian Trixie)
INTERFACE=$(ip route | grep default | awk '{print $5}')
systemctl start vnstat
systemctl enable vnstat

# 3. Criação de Usuários e Pastas
for USERNAME in "admin" "jutair"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Estrutura necessária para o menu funcionar
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Injeção do Menu no login (Importante: Usa o caminho absoluto)
        echo "if [ -f $DIR_SCRIPTS/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash $DIR_SCRIPTS/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
        
        chown -R $USERNAME:$USERNAME /home/$USERNAME
    fi
done

# 4. Permissões sem senha para o Menu
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

# 5. Permissões finais nos scripts
chmod +x "$DIR_SCRIPTS"/*.sh

echo "Configuração concluída. Removendo instalador..."
rm -f "$HOME/setup_vps.sh"*
