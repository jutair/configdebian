#!/bin/bash
# setup_vps.sh - O Gatilho

AZUL='\033[0;34m'
NC='\033[0m'

clear
echo -e "${AZUL}Limpando arquivos antigos e preparando instalação...${NC}"
# Remove vestígios para evitar o erro do .1, .2
rm -f setup_vps.sh* main.zip
rm -rf $HOME/configdebian-main

apt-get update && apt-get install -y wget unzip curl

echo -e "${AZUL}Baixando repositório...${NC}"
wget https://github.com/jutair/configdebian/archive/refs/heads/main.zip

unzip -o main.zip -d $HOME/
DIR_SCRIPTS="$HOME/configdebian-main"

if [ -f "$DIR_SCRIPTS/configura_sistema.sh" ]; then
    chmod +x "$DIR_SCRIPTS"/*.sh
    bash "$DIR_SCRIPTS/configura_sistema.sh"
else
    echo "Erro: Pasta não encontrada."
    exit 1
fi
