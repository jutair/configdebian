# Define as variáveis de cor
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m' # Negrito e Amarelo
NC='\033[0m' # No Color / Reset
echo -e "${VERDE}Isso é uma mensagem de sucesso em verde.${NC}"
echo **********************************************************************************************************************
echo Iniciando a configiguração
echo **********************************************************************************************************************
echo Inslatando o comando sudo
echo **********************************************************************************************************************
apt install sudo -y
echo **********************************************************************************************************************
echo Criando os usuários
#sudo useradd -G sudo sudo -m jutair -s /bin/bash //Apenas em servidor VPS
echo sudo passwd jutair //Apenas em servidor VPS
#sudo usermod -aG sudo jutair
sudo useradd -G sudo -m guest -s /bin/bash
sudo passwd guest
echo **********************************************************************************************************************
echo Atualizando o sistema...
echo **********************************************************************************************************************
sudo apt update && sudo apt upgrade -y
echo **********************************************************************************************************************
echo Instalando os pacote basicos de rede
sudo apt install net-tools -y
echo Instalando o Samba
sudo apt install samba -y
echo **********************************************************************************************************************
echo Instalando os pacotes para SSH
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
echo **********************************************************************************************************************
echo Instalado os pacotes OpenVPN
sudo apt install openvpn -y
sudo apt install easy-rsa -y
echo **********************************************************************************************************************
echo Fazendo backup das configurações básicas do sistema
cd /home/jutair
mkdir Backup
cp /etc/ssh/sshd_config /home/jutair/Backup
cp /etc/samba/smb.conf /home/jutair/Backup
cd
echo **********************************************************************************************************************
echo Baixando as configurações do OpenVPN
wget https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
echo **********************************************************************************************************************
echo Configurando o SSH
echo **********************************************************************************************************************
echo Criando Popule o Diretório do Easy-RSA
cd
mkdir ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
cd ~/easy-rsa
echo **********************************************************************************************************************
echo Criando o PKI
./easyrsa init-pki
echo **********************************************************************************************************************
echo Criando a autoridade certificadora
./easyrsa build-ca nopass
echo **********************************************************************************************************************
echo Assinando o Certificado do Servidor
./easyrsa gen-req server nopass
./easyrsa gen-dh
echo **********************************************************************************************************************
echo Enviando o certificado para OpenVPN
sudo cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/
echo **********************************************************************************************************************
echo Configurando o SSH
sudo cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/
echo **********************************************************************************************************************
echo Configurando SSH Finalizada
echo **********************************************************************************************************************
echo Instalado o Firewall
sudo apt install ufw -y
echo **********************************************************************************************************************
echo Configurando o Firewall
sudo ufw allow ssh
sudo ufw allow 1194/udp
sudo ufw allow 443/udp
sudo ufw enable
echo **********************************************************************************************************************
echo Baixando os parâmetros do Servidor SSH
echo Baixando as confiurações do Samba
echo Baixando os scripts de backup
echo **********************************************************************************************************************
echo Saindo...
cd
echo Logue com o seu usuário
echo -e "${VERMELHO}Isso é um erro em vermelho!${NC}"
exit
exit

