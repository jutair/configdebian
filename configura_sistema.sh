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
    fi

    # --- LIMPEZA TOTAL DO BASHRC ---
    # Remove linhas que causavam erros de 'No such file' ou 'cp/chmod' no login
    sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
    sed -i '/cp /d' /home/$USERNAME/.bashrc
    sed -i '/chmod /d' /home/$USERNAME/.bashrc
    sed -i '/configdebian/d' /home/$USERNAME/.bashrc
    sed -i '/Configuração completa/d' /home/$USERNAME/.bashrc

    # Adiciona a única linha necessária para o menu funcionar
    echo "sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
    
    # Garante que o usuário é dono da sua própria pasta home
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissões de Sudo (Essencial para o menu rodar sem senha)
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users
chmod 440 /etc/sudoers.d/90-vpn-users

# 4. Ajuste final de permissões na pasta dos scripts
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo "Instalação concluída com sucesso!"
