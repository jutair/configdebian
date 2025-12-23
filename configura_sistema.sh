#!/bin/bash
# configura_sistema.sh - Configuração Única da Máquina

DIR_ORIGEM="/tmp/configdebian-main"
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# 1. Verificação de privilégios
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Este script precisa ser rodado como ROOT.${NC}"
  exit 1
fi

echo -e "${VERDE}Iniciando Instalação de Pacotes e Dependências...${NC}"
apt update && apt upgrade -y
apt install sudo htop ntpsec-ntpdate net-tools samba nload iftop speedtest-cli vnstat sysstat tcpdump openssh-server ufw bc fail2ban curl unzip -y

# 2. Configuração de Hora e Local
timedatectl set-timezone America/Manaus
ntpdate-debian

# 3. Configuração de Firewall (Portas essenciais)
ufw allow 22/tcp
ufw allow 1194/udp
ufw allow 4004/tcp
echo "y" | ufw enable

# 4. Função para criar perfis com permissões distintas
configurar_perfil() {
    local USER=$1
    local SENHA=$2
    local EH_ADMIN=$3  # true para jutair, false para guest

    echo -e "${AMARELO}Configurando usuário: $USER...${NC}"
    
    # Cria o usuário
    useradd -m -s /bin/bash "$USER" 2>/dev/null
    echo "$USER:$SENHA" | chpasswd

    # Se for admin (jutair), adiciona ao grupo sudo
    if [ "$EH_ADMIN" = "true" ]; then
        usermod -aG sudo "$USER"
    fi

    # Criar pastas de trabalho e Backup
    mkdir -p "/home/$USER/configdebian-main"
    mkdir -p "/home/$USER/Backup"
    
    # Copia os scripts do repositório para a home do usuário
    if [ -d "$DIR_ORIGEM" ]; then
        cp -r "$DIR_ORIGEM"/* "/home/$USER/configdebian-main/"
    fi
    
    # Configuração de SSH Keys (Copia do root para facilitar seu acesso)
    mkdir -p "/home/$USER/.ssh"
    if [ -f /root/.ssh/authorized_keys ]; then
        cp /root/.ssh/authorized_keys "/home/$USER/.ssh/"
    fi
    
    # Ajuste de Permissões (Dono da pasta deve ser o usuário)
    chown -R "$USER:$USER" "/home/$USER"
    chmod 700 "/home/$USER/.ssh"
    chmod -R +x "/home/$USER/configdebian-main"/*.sh
}

# --- EXECUÇÃO DA CRIAÇÃO ---
# Jutair: Com poderes de ROOT (Sudo)
configurar_perfil "jutair" "SUA_SENHA_AQUI" "true"

# Guest: SEM poderes de ROOT (Usuário comum)
configurar_perfil "guest" "SENHA_GUEST_AQUI" "false"

# 5. CONFIGURAÇÃO DO SUDOERS (A parte mais importante)
# Limpa regras antigas se existirem e adiciona as novas
sed -i '/jutair ALL=/d' /etc/sudoers
sed -i '/guest ALL=/d' /etc/sudoers

# Jutair tem poder total sem senha
echo "jutair ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Guest só pode rodar o MENU e os SCRIPTS dentro da pasta dele via sudo (necessário para funções de rede)
echo "guest ALL=(ALL) NOPASSWD: /home/guest/configdebian-main/*.sh" >> /etc/sudoers

# 6. CONFIGURAÇÃO GLOBAL DE AUTO-START
# Isso faz o menu abrir automaticamente para qualquer um dos dois ao logar
cat <<EOF > /etc/profile.d/vpn_menu.sh
if [[ -t 0 ]]; then
    if [ -f "\$HOME/configdebian-main/menu.sh" ]; then
        sudo -E bash "\$HOME/configdebian-main/menu.sh"
    fi
fi
EOF
chmod +x /etc/profile.d/vpn_menu.sh

echo -e "${VERDE}Configuração concluída! Usuários criados e scripts distribuídos.${NC}"
