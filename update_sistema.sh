#!/bin/bash

# Detecta o usuário humano para definir os caminhos
NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
DESTINO="/home/$NOME_USUARIO/configdebian-main"

# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mErro: Por favor execute esse script como sudo/root!\033[0m"
  exit 1
fi

echo "=========================================================================="
echo "Verificando e instalando dependências do instalador..."
echo "=========================================================================="
# Lista de dependências necessárias para o instalador funcionar
DEPENDENCIAS=(sudo wget curl unzip coreutils)

apt update -y
for pacote in "${DEPENDENCIAS[@]}"; do
    if ! dpkg -s "$pacote" >/dev/null 2>&1; then
        echo -e "\033[33mInstalando dependência ausente: $pacote\033[0m"
        apt install -y "$pacote"
    fi
done

echo "=========================================================================="
echo "Buscando por atualização dos pacotes no repositório do Debian..."
echo "=========================================================================="
apt upgrade -y

echo "=========================================================================="
echo "Baixando scripts do GitHub..."
echo "=========================================================================="
wget -qO "/home/$NOME_USUARIO/main.zip" "https://github.com/jutair/configdebian/archive/refs/heads/main.zip"

echo "=========================================================================="
echo "Extraindo os scripts para pasta do usuário..."
echo "=========================================================================="
unzip -o "/home/$NOME_USUARIO/main.zip" -d "/home/$NOME_USUARIO/"
rm "/home/$NOME_USUARIO/main.zip"

# Garante que o usuário humano seja o dono da pasta extraída
chown -R "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"

echo "=========================================================================="
echo "Baixando o script do OpenVPN do Angristan..."
echo "=========================================================================="
wget -qO "$DESTINO/openvpn-install.sh" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x "$DESTINO/openvpn-install.sh"
chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO/openvpn-install.sh"

echo "=========================================================================="
echo "Limpando arquivos de instalação e configurando permissões..."
echo "=========================================================================="
cd "$DESTINO" || exit

# 1. Dá permissão de execução aos scripts de gestão diária
chmod +x menu.sh open_vpn_conf.sh usuarios.sh update_sistema.sh gerencia_rede.sh

# 2. APAGA os scripts que não devem ser rodados novamente (Autodestruição)
# Removemos o configurador e este próprio instalador da pasta de destino final
rm -f configura_sistema.sh setup_vps.sh

echo "=========================================================================="
echo "Configuração concluída! Iniciando o sistema..."
echo "=========================================================================="
sleep 2

# Inicia o menu diretamente como o usuário correto preservando o ambiente
exec sudo -E -u "$NOME_USUARIO" bash ./menu.sh
