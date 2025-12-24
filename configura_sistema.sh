# --- PARTE DO VNSTAT ---
# Em versões novas, apenas garantimos que ele saiba qual interface olhar
INTERFACE=$(ip route | grep default | awk '{print $5}')
# Se o arquivo de config existir, garantimos a interface lá
sed -i "s/Interface \".*\"/Interface \"$INTERFACE\"/" /etc/vnstat.conf 2>/dev/null
systemctl restart vnstat

# --- PARTE DA CRIAÇÃO DE USUÁRIOS E PERMISSÕES ---
# Certifique-se de que a variável DIR_SCRIPTS aponta para onde o setup extraiu
DIR_SCRIPTS="$HOME/configdebian-main"

# Criar usuários (admin e jutair)
for USERNAME in "admin" "jutair"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        
        # Criar pastas essenciais
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Injetar o menu no login
        echo "if [ -f $DIR_SCRIPTS/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash $DIR_SCRIPTS/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
        
        chown -R $USERNAME:$USERNAME /home/$USERNAME
    fi
done

# --- CORREÇÃO DO CHMOD ---
# Dá permissão em todos os .sh onde quer que a pasta esteja
find "$HOME" -name "*.sh" -exec chmod +x {} +

# --- LIMPEZA FINAL ---
rm -f "$HOME/setup_vps.sh"*
rm -f "$HOME/main.zip"
