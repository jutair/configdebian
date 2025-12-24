#!/bin/bash
# setup_vps.sh

apt-get update && apt-get install -y wget unzip curl

# Baixa e Extrai
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip
unzip -o /tmp/main.zip -d /tmp/

# Move para o local global (ROOT faz isso aqui, uma única vez)
mkdir -p /opt/configdebian
cp -r /tmp/configdebian-main/* /opt/configdebian/
chmod +x /opt/configdebian/*.sh

# Chama o configurador
bash /opt/configdebian/configura_sistema.sh

# Limpa
rm -rf /tmp/main.zip /tmp/configdebian-main
