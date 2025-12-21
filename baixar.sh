USER=${SUDO_USER:-$(whoami)}
# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como sudo!"
  echo -e "\033[31msudo ./configura_sistema.sh"
  echo -e "\033[0m"
  exit 1
fi
apt install sudo -y
sudo apt install unzip -y
wget https://github.com/jutair/configdebian/archive/refs/heads/main.zip
unzip main.zip
sudo rm main.zip
cd /home/$USER/configdebian-main
chmod +x configura_sistema.sh
chmod +x menu.sh
chmod +x open_vpn_conf.sh
chmod +x usuarios.sh
sudo ./configura_sistema.sh
