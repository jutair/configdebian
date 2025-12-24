#!/bin/bash
# update_sistema.sh - Atualizador Global em /opt/configdebian
# Responsável por baixar scripts do GitHub, aplicar permissões e reiniciar o menu

set -e

AZUL='\033[0;34m'
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'

DESTINO="/opt/configdebian"
TEMP_ZIP="/tmp/main.zip"
TEMP_EXTRACT="/tmp/configdebian-update"
REPO_ZIP="https://github.com/jutair/configdebian/archive/refs/heads/main.zip"

echo -e "${AZUL}===============================================================${NC}"
echo -e "              ATUALIZAÇÃO GERAL DO SISTEMA"
echo -e "${AZUL}===============================================================${NC}"

# 1️⃣ Atualiza pacotes do sistema
echo -e "${AZUL}[1/2]${NC} Atualizando pacotes do sistema (apt)..."
sudo apt update && sudo apt upgrade -y

# 2️⃣ Atualiza scripts do repositório
echo -e "\n${AZUL}[2/2]${NC} Atualizando scripts do GitHub em $DESTINO..."

# Verifica se wget e unzip estão disponíveis
command -v wget >/dev/null || { echo -e "${VERMELHO}wget não encontrado!${NC}"; exit 1; }
command -v unzip >/dev/null || { echo -e "${VERMELHO}unzip não encontrado!${NC}"; exit 1; }

# Baixa o zip mais recente
wget -q $REPO_ZIP -O $TEMP_ZIP || { echo -e "${VERMELHO}Falha ao baixar o repositório.${NC}"; exit 1; }

# Extrai para pasta temporária
rm -rf $TEMP_EXTRACT
mkdir -p $TEMP_EXTRACT
unzip -o $TEMP_ZIP -d $TEMP_EXTRACT > /dev/null

# Detecta a pasta extraída dinamicamente
EXTRACTED_DIR=$(find $TEMP_EXTRACT -maxdepth 1 -type d -name "configdebian-*")
if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${VERMELHO}✘ Não foi possível localizar o diretório extraído.${NC}"
    exit 1
fi

# Copia scripts para /opt/configdebian
mkdir -p $DESTINO
cp -r $EXTRACTED_DIR/* $DESTINO/

# Ajusta permissões
chown -R root:sudo $DESTINO
chmod -R 775 $DESTINO
chmod +x $DESTINO/*.sh

# Limpa temporários
rm -rf $TEMP_EXTRACT $TEMP_ZIP

echo -e "${VERDE}✔ Scripts atualizados com sucesso em $DESTINO!${NC}"
echo -e "${AZUL}===============================================================${NC}"

# 3️⃣ Reinicia o menu
read -p "Pressione ENTER para reiniciar o menu..." dummy
exec bash $DESTINO/menu.sh
