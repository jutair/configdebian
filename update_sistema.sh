#!/bin/bash
NOME_USUARIO=$(logname)
DESTINO="/home/$NOME_USUARIO/configdebian-main"

# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como sudo!\033[0m"
  exit 1
fi
echo "=========================================================================="
echo "Buscando por atualização dos pacotes no repositório do debian..."
echo "=========================================================================="
sudo apt update && sudo apt upgrade -y

echo "=========================================================================="
echo "Baixando os scripts no repositório do github..."
echo "=========================================================================="
sudo wget -O /home/${NOME_USUARIO}/main.zip" "https://github.com/jutair/configdebian/archive/refs/heads/main.zip

echo "=========================================================================="
echo "Extraindo os scripts para pasta do usuário..."
echo "=========================================================================="
unzip -o /home/${NOME_USUARIO}/main.zip -d /home/${NOME_USUARIO}/
sudo rm /home/${NOME_USUARIO}/main.zip

echo "=========================================================================="
echo "Acessando os novos scripts na pasta do usuário..."
echo "=========================================================================="
cd "$DESTINO" || exit

################ Abre a permissão para os arquivos ################################
chmod +x configura_sistema.sh menu.sh open_vpn_conf.sh usuarios.sh update_sistema.sh

echo "=========================================================================="
echo "Atualização concluída! Iniciando o sistema..."
echo "=========================================================================="
sleep 10 #aumenta o tempo 
sudo ./menu.sh
