#!/bin/bash
# configura_sistema.sh - O Construtor da VPS

AZUL='\033[0;34m'
VERDE='\033[0;32m'
NC='\033[0m'

echo -e "${AZUL}Iniciando configuração pesada do sistema...${NC}"

# 1. ATUALIZAÇÃO E DEPENDÊNCIAS ESSENCIAIS
apt-get update && apt-get upgrade -y
apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 2. CONFIGURAÇÃO DE REDE (VnStat e Firewall)
# Detecta a interface de rede ativa para o VnStat não ficar zerado
INTERFACE=$(ip route | grep default | awk '{print $5}')
vnstat -u -i "$INTERFACE"
systemctl restart vnstat

# 3. CRIAÇÃO DE USUÁRIOS E ESTRUTURA DE PASTAS
# Lista de usuários que você deseja criar (Exemplo: jutair e suporte)
USUARIOS=("jutair" "admin")

for USERNAME in "${USUARIOS[@]}"; do
    if ! id "$USERNAME" &>/dev/null; then
        echo -e "${VERDE}Criando usuário: $USERNAME...${NC}"
        # Cria usuário com shell bash e home
        useradd -m -s /bin/bash "$USERNAME"
        # Define uma senha padrão (Altere após o primeiro login)
        echo "$USERNAME:Senha123" | chpasswd
        
        # Adiciona ao grupo sudo
        usermod -aG sudo "$USERNAME"
        
        # Cria a estrutura de pastas que seus scripts exigem
        mkdir -p /home/$USERNAME/Backup
        mkdir -p /home/$USERNAME/clientes_ovp
        mkdir -p /home/$USERNAME/transfer
        
        # Ajusta permissões para o usuário ser dono da sua home
        chown -R $USERNAME:$USERNAME /home/$USERNAME
        
        # 4. CONFIGURAÇÃO DE LOGIN AUTOMÁTICO NO MENU
        # Faz o menu iniciar assim que o usuário logar no SSH
        echo "if [ -f ~/configdebian-main/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash ~/configdebian-main/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
    fi
done

# 5. PERMISSÃO SUDO SEM SENHA (Para o Menu não engasgar)
# Permite que os usuários do grupo sudo rodem o menu sem pedir senha toda hora
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-cloud-init-users

# 6. FINALIZAÇÃO DAS PERMISSÕES DO REPOSITÓRIO
# Garante que todos os scripts baixados sejam executáveis
chmod +x $HOME/configdebian-main/*.sh

echo -e "${VERDE}Configuração concluída! Reiniciando serviços...${NC}"
systemctl restart ssh
