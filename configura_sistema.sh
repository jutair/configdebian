# Variáveis de cores
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m' # Negrito e Amarelo
NC='\033[0m' # No Color / Reset
echo **********************************************************************************************************************
echo -e "${VERDE}Iniciando a configuração${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Inslatando o comando sudo${NC}"
echo **********************************************************************************************************************
apt install sudo -y
echo **********************************************************************************************************************
echo -e "${AMARELO}Atualizando o sistema${NC}"
echo **********************************************************************************************************************
sudo apt update && sudo apt upgrade -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando as ferramentas basicas do sistema${NC}"
sudo apt install htop -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes básicos de rede${NC}"
sudo apt install net-tools -y
echo -e "${VERDE}Instalando o Samba${NC}"
sudo apt install samba -y
echo -e "${VERDE}Instalando o Nload${NC}"
sudo apt install nload -y
echo -e "${VERDE}Instalando o IF-top${NC}"
sudo apt install iftop -y
echo -e "${VERDE}Instalando o Speedtest${NC}"
sudo apt install speedtest-cli -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes para SSH${NC}"
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes para o OpenVPN${NC}"
sudo apt install openvpn -y
sudo apt install easy-rsa -y
echo -e "${VERDE}Instalando NetData${NC}"
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh
echo **********************************************************************************************************************
echo -e "${AMARELO}Baixano as configurações do OpenVPN..${NC}"
cd /home/jutair
wget https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
echo **********************************************************************************************************************
echo -e "${VERDE}Confiurando o SSH${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Criando Popule o Diretório do Easy-RSA${NC}"
cd
mkdir ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
cd ~/easy-rsa
echo **********************************************************************************************************************
echo -e "${VERDE}Criando o PKI${NC}"
./easyrsa init-pki
echo **********************************************************************************************************************
echo -e "${VERDE}Criando a autoridade certificadora${NC}"
./easyrsa build-ca nopass
echo **********************************************************************************************************************
echo -e "${VERDE}Assinando o Certificado do Servidor${NC}"
./easyrsa gen-req server nopass
./easyrsa gen-dh
echo **********************************************************************************************************************
echo -e "${VERDE}Enviando o certificado para OpenVPN${NC}"
sudo cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/
echo **********************************************************************************************************************
echo -e "${VERDE}Configurando o SSH${NC}"
sudo cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/
echo **********************************************************************************************************************
echo -e "${VERDE}Configurando SSH Finalizada${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Instalado o Firewall${NC}"
sudo apt install ufw -y
echo **********************************************************************************************************************
echo -e "${VERDE}Configurando o Firewall${NC}"
sudo ufw allow ssh
echo -e "${VERDE}Permitindo UDP na porta 1194${NC}"
sudo ufw allow 1194/udp
echo -e "${VERDE}Permitindo TCP na porta 4004${NC}"
sudo ufw allow 4004/tcp
echo -e "${Amarelo}Permitindo TCP na Porta 22${NC}"
sudo ufw allow 22/tcp
echo -e "${Amarelo}Iniciando Firewalll...${NC}"
sudo ufw enable
echo -e "${VERDE}Firewall Iniciado!${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Criando os usuários${NC}"
####################################Apenas em servidor VPS#################################################################
sudo useradd -G sudo -m jutair -s /bin/bash ##Apenas em servidor VPS
sudo passwd jutair
sudo usermod -aG sudo jutair
# Cria a pasta .ssh no novo usuário
mkdir -p /home/jutair/.ssh
# Copia as chaves autorizadas do root para o usuário
cp /root/.ssh/authorized_keys /home/jutair/.ssh/
# Ajusta as permissões
chown -R root:jutair /home/jutair/.ssh
chmod 700 /home/jutair/.ssh
chmod 600 /home/jutair/.ssh/authorized_keys
###########################################################################################################################
sudo useradd -G sudo -m guest -s /bin/bash
sudo passwd guest
# Cria a pasta .ssh no novo usuário
mkdir -p /home/guest/.ssh
# Copia as chaves autorizadas do root para o usuário
cp /root/.ssh/authorized_keys /home/jutair/.ssh/
# Ajusta as permissões
# O SSH não funciona se as permissões estiverem abertas demais
chown -R root:guest /home/guest/.ssh
chmod 700 /home/guest/.ssh
chmod 600 /home/guest/.ssh/authorized_keys
echo **********************************************************************************************************************
echo -e "${VERDE}Fazendo BACKUP das configurações${NC}"
cd /home/jutair
mkdir Backup
cp /etc/ssh/sshd_config /home/jutair/Backup
cp /etc/samba/smb.conf /home/jutair/Backup
cd
echo **********************************************************************************************************************
echo Baixando os parâmetros do Servidor SSH
echo Baixando as confiurações do Samba
echo Baixando os scripts de backup
echo **********************************************************************************************************************
echo -e "${AMARELO}Saindo...${NC}"
echo -e "${AMARELO}Logue com o seu usuário${NC}"
echo -e "${VERMELHO}Scriptfinalizado${NC}"
cd
exit
exit

