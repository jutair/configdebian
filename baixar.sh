if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como root!"
  echo -e "\033[31mDe o comando su antes de executar esse script"
  echo -e "\033[0m"
  exit 1
fi
# Pega o nome do primeiro usuário humano criado no sistema
USUARIO_HUMANO=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)
# Pega a home desse usuário
HOME_HUMANA=$(getent passwd "$USUARIO_HUMANO" | cut -d: -f6)
echo "A pasta home detectada foi: $HOME_HUMANA"
# Verifica se o script foi executado como root
apt update && apt upgrade -y
apt install sudo -y
sudo apt install unzip -y
wget https://github.com/jutair/configdebian/archive/refs/heads/main.zip
unzip main.zip
sudo rm main.zip
USER=${SUDO_USER:$(logname)
cd $HOME_HUMANA/configdebian-main
chmod +x configura_sistema.sh
chmod +x menu.sh
chmod +x open_vpn_conf.sh
chmod +x usuarios.sh
sudo ./configura_sistema.sh
