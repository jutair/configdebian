echo ######################################################################################################################
echo Iniciando a configiguração
echo ######################################################################################################################
echo Inslatando o comando sudo
echo ######################################################################################################################
apt install sudo -y
echo ######################################################################################################################
echo Criando os usuários
echo sudo useradd -G sudo sudo -m jutair -s /bin/bash //Apenas em servidor VPS
echo sudo passwd jutair //Apenas em servidor VPS
sudo usermod aG jutair
sudo useradd -G sudo sudo -m guest -s /bin/bash
sudo passwd guest
echo ######################################################################################################################
echo Atualizando o sistema...
echo ######################################################################################################################
sudo apt update && sudo apt upgrade -y
echo ######################################################################################################################
echo Instalando os pacote basicos de rede
sudo apt install net-tools -y
sudo apt install samba - y
echo ######################################################################################################################
echo Instalando os pacotes para SSH
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
echo ######################################################################################################################
echo Instalado os pacotes OpenVPN
sudo apt install openvpn -y
sudo apt install easy-rsa -y
echo ######################################################################################################################
echo Fazendo backup das configurações básicas do sistema
cd /home/jutair/Backup
cp /etc/ssh/sshd_config /home/jutair/Backup
cp /etc/samba/smb.conf /home/jutair/Backup
echo ######################################################################################################################
echo Baixando as configurações do OpenVPN
wget https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
echo ######################################################################################################################
echo Baixando as confiurações do SSH
echo Baixando as confiurações do Samba
echo Baixando os scripts de backup
