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
echo -e "${VERDE}Criando os usuários${NC}"
#sudo useradd -G sudo sudo -m jutair -s /bin/bash //Apenas em servidor VPS
#sudo passwd jutair //Apenas em servidor VPS
#sudo usermod -aG sudo jutair
sudo useradd -G sudo -m guest -s /bin/bash
sudo passwd guest
echo **********************************************************************************************************************
echo -e "${AMARELO}Atualizando o sistema${NC}"
echo **********************************************************************************************************************
sudo apt update && sudo apt upgrade -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes básicos de rede${NC}"
sudo apt install net-tools -y
echo -e "${VERDE}Instalando o Samba${NC}"
sudo apt install samba -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes para SSH${NC}"
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes para o OpenVPN${NC}"
sudo apt install openvpn -y
sudo apt install easy-rsa -y
echo **********************************************************************************************************************
echo -e "${VERDE}Fazendo BACKUP das configurações${NC}"
cd /home/jutair
mkdir Backup
cp /etc/ssh/sshd_config /home/jutair/Backup
cp /etc/samba/smb.conf /home/jutair/Backup
cd
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
echo -e "${VERDE}Permitindo UDP na porta 4004${NC}"
sudo ufw allow 4004/tcp
echo -e "${Amarelo}Iniciando Firewalll...${NC}"
sudo ufw enable
echo -e "${VERDE}Firewall Iniciado!${NC}"
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

