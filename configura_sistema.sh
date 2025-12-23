#!/bin/bash
# configura_sistema.sh - Configuração de Máquina e Organização de Pastas

# --- VARIÁVEIS DE AMBIENTE ---
DIR_ORIGEM="/tmp/configdebian-main"
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- 1. VERIFICAÇÃO DE PRIVILÉGIOS ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Este script precisa ser executado como ROOT.${NC}"
  exit 1
fi

echo -e "${VERDE}******************************************************************${NC}"
echo -e "${VERDE}          INICIANDO CONFIGURAÇÃO ÚNICA DA MÁQUINA                 ${NC}"
echo -e "${VERDE}******************************************************************${NC}"

# --- 2. ATUALIZAÇÃO E INSTALAÇÃO DE PACOTES ---
echo -e "${AMARELO}Instalando dependências e ferramentas de rede...${NC}"
apt update && apt upgrade -y
apt install sudo htop ntpsec-ntpdate net-tools samba nload iftop speedtest-cli \
vnstat sysstat tcpdump openssh-server ufw bc fail2ban curl unzip -y

# Ajuste de Hora e Fuso Horário
timedatectl set-timezone America/Manaus
ntpdate-debian
timedatectl set-ntp true

# --- 3. CONFIGURAÇÃO DE SEGURANÇA (FIREWALL) ---
echo -e "${AMARELO}Configurando Firewall (UFW)...${NC}"
ufw allow 22/tcp   # SSH
ufw allow 1194/udp # OpenVPN
ufw allow 4004/tcp # Porta extra
echo "y" | ufw enable

# --- 4. FUNÇÃO PARA CONFIGURAR PERFIS DE USUÁRIOS ---
configurar_perfil() {
    local USER=$1
    local SENHA=$2
    local EH_ADMIN=$3  # true para jutair, false para guest

    echo -e "${VERDE}Criando e organizando ambiente para: $USER...${NC}"
    
    # Cria o usuário com shell bash
    useradd -m -s /bin/bash "$USER" 2>/dev/null
    echo "$USER:$SENHA" | chpasswd

    # Define permissão de administrador se for o caso
    if [ "$EH_ADMIN" = "true" ]; then
        usermod -aG sudo "$USER"
    fi

    # Criar a estrutura de pastas solicitada
    mkdir -p "/home/$USER/Backup"
    mkdir -p "/home/$USER/clientes_ovp"
    mkdir -p "/home/$USER/transfer"
    mkdir -p "/home/$USER/configdebian-main"
    
    # Copia os scripts do repositório (/tmp) para a home do usuário
    if [ -d "$DIR_ORIGEM" ]; then
        cp -r "$DIR_ORIGEM"/* "/home/$USER/configdebian-main/"
    fi

    # --- 5. BACKUP AUTOMÁTICO DE CONFIGURAÇÕES ---
    echo "    Salvando backups iniciais em /home/$USER/Backup..."
    [ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config "/home/$USER/Backup/sshd_config.bak"
    [ -f /etc/samba/smb.conf ] && cp /etc/samba/smb.conf "/home/$USER/Backup/smb.conf.bak"

    # Configuração de SSH Key (Copia do root se existir)
    mkdir -p "/home/$USER/.ssh"
    if [ -f /root/.ssh/authorized_keys ]; then
        cp /root/.ssh/authorized_keys "/home/$USER/.ssh/"
    fi

    # Ajuste Final de Permissões (Dono da pasta deve ser o usuário)
    chown -R "$USER:$USER" "/home/$USER"
    chmod 700 "/home/$USER/.ssh"
    chmod 600 "/home/$USER/.ssh/authorized_keys" 2>/dev/null
    chmod -R +x "/home/$USER/configdebian-main"/*.sh
}

# --- 6. EXECUÇÃO DOS PERFIS ---
# Jutair: Usuário com poderes de ROOT
configurar_perfil "jutair" "SUA_SENHA_AQUI" "true"

# Guest: Usuário comum (Sem ROOT)
configurar_perfil "guest" "SENHA_GUEST_AQUI" "false"

# --- 7. CONFIGURAÇÃO DE SUDOERS (CONTROLE DE ACESSO) ---
# Limpa regras antigas e define as novas
sed -i '/jutair ALL=/d' /etc/sudoers
sed -i '/guest ALL=/d' /etc/sudoers

# Jutair: Total liberdade
echo "jutair ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Guest: Só pode rodar os scripts da sua pasta via sudo (necessário para rede/vpn)
echo "guest ALL=(ALL) NOPASSWD: /home/guest/configdebian-main/*.sh" >> /etc/sudoers

# --- 8. CONFIGURAÇÃO DE AUTO-START (MENU NO LOGIN) ---
cat <<EOF > /etc/profile.d/vpn_menu.sh
if [[ -t 0 ]]; then
    if [ -f "\$HOME/configdebian-main/menu.sh" ]; then
        sudo -E bash "\$HOME/configdebian-main/menu.sh"
    fi
fi
EOF
chmod +x /etc/profile.d/vpn_menu.sh

echo -e "${VERDE}******************************************************************${NC}"
echo -e "${VERDE} CONFIGURAÇÃO CONCLUÍDA! REINICIE O LOGIN PARA ACESSAR O MENU.    ${NC}"
echo -e "${VERDE}******************************************************************${NC}"
