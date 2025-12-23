#!/bin/bash
NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
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
echo "Baixando scripts do GitHub..."
echo "=========================================================================="
# Usando o -O para garantir que sobrescreva o arquivo antigo se houver
sudo wget -O "/home/$NOME_USUARIO/main.zip" "https://github.com/jutair/configdebian/archive/refs/heads/main.zip"

echo "=========================================================================="
echo "Extraindo os scripts para pasta do usuário..."
echo "=========================================================================="
sudo unzip -o "/home/$NOME_USUARIO/main.zip" -d "/home/$NOME_USUARIO/"
sudo rm "/home/$NOME_USUARIO/main.zip"

# Garante que os arquivos pertençam ao usuário correto
sudo chown -R "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"

echo "=========================================================================="
echo "Acessando e dando permissão aos novos scripts..."
echo "=========================================================================="
cd "$DESTINO" || exit

# Dá permissão de execução a todos os scripts necessários
chmod +x configura_sistema.sh menu.sh open_vpn_conf.sh usuarios.sh update_sistema.sh

echo "=========================================================================="
echo "Atualização concluída! Reiniciando o painel..."
echo "=========================================================================="
sleep 2

# A MUDANÇA CHAVE: exec substitui o script de update pelo menu.
# Isso limpa a pilha de processos e evita que o menu fique "preso"
exec sudo ./menu.sh
