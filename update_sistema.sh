#!/bin/bash
NOME_USUARIO=${SUDO_USER:-$(whoami)}
DESTINO="/home/$NOME_USUARIO/configdebian-main"

# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como sudo!\033[0m"
  exit 1
fi

############ Verifica se já existe o script update_sistema.sh na pasta home ############
ARQUIVOS=$(find "/home/${NOME_USUARIO}/update_sistema.sh" ! -path "$DESTINO/*" 2>/dev/null)

if [ -z "$ARQUIVOS" ]; then
    echo -e "Não foi encontrado script de atualização na pasta home!"
    echo -e "Baixando um novo script..."
else
    echo "Removendo o script antigo da pasta home."
    sudo rm "/home/${NOME_USUARIO}/update_sistema.sh"
fi

#################################################################################
sudo wget -P "/home/${NOME_USUARIO}" "https://link_do_seu_script/update_sistema.sh"
sudo chmod +x "/home/${NOME_USUARIO}/update_sistema.sh"

sudo "/home/${NOME_USUARIO}/update_sistema.sh"

# Remove a pasta antiga se existir
[ -d "$DESTINO" ] && rm -rf "$DESTINO"

echo "=========================================================================="
echo "Buscando por atualização dos pacotes no repositório do debian..."
echo "=========================================================================="
sudo apt update && sudo apt upgrade -y

echo "=========================================================================="
echo "Baixando os scripts no repositório do github..."
echo "=========================================================================="
sudo wget -O "/home/${NOME_USUARIO}/main.zip" "https://github.com/jutair/configdebian/archive/refs/heads/main.zip"

echo "=========================================================================="
echo "Extraindo os scripts para pasta do usuário..."
echo "=========================================================================="
unzip -o "/home/${NOME_USUARIO}/main.zip" -d "/home/${NOME_USUARIO}/"
sudo rm "/home/${NOME_USUARIO}/main.zip"

echo "=========================================================================="
echo "Acessando os novos scripts na pasta do usuário..."
echo "=========================================================================="
cd "$DESTINO" || exit

################ Abre a permissão para os arquivos ################################
chmod +x configura_sistema.sh menu.sh open_vpn_conf.sh usuarios.sh update_sistema.sh

echo "=========================================================================="
echo "Atualização concluída! Iniciando o sistema..."
echo "=========================================================================="
sleep 2
sudo ./menu.sh
