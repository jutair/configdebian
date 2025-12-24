#!/bin/bash
# setup_vps.sh - O Gatilho de Instalação

# Cores para o terminal
AZUL='\033[0;34m'
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'

clear
echo -e "${AZUL}===============================================================${NC}"
echo -e "            INSTALADOR AUTOMÁTICO - CONFIG DEBIAN"
echo -e "${AZUL}===============================================================${NC}"

# 1. Verificação de privilégios
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, execute este script como ROOT (sudo su).${NC}"
  exit 1
fi

# 2. Instalação de dependências mínimas para extração
echo -e "${AZUL}[1/4]${NC} Preparando ambiente básico..."
apt-get update -y && apt-get install -y wget unzip curl

# 3. Limpeza de instalações antigas e download do repositório
echo -e "${AZUL}[2/4]${NC} Descarregando repositório do GitHub..."
DIR_DESTINO="$HOME/configdebian-main"
rm -rf "$DIR_DESTINO" # Remove se já existir para atualizar
rm -f main.zip

wget https://github.com/jutair/configdebian/archive/refs/heads/main.zip

# 4. Extração dos ficheiros
if [ -f main.zip ]; then
    echo -e "${AZUL}[3/4]${NC} Extraindo ficheiros..."
    unzip -o main.zip -d $HOME/
    rm main.zip
else
    echo -e "${VERMELHO}Erro: Falha ao descarregar o repositório.${NC}"
    exit 1
fi

# 5. Permissões e Início da Configuração Pesada
echo -e "${AZUL}[4/4]${NC} Iniciando configuração do sistema..."
chmod +x "$DIR_DESTINO"/*.sh

if [ -f "$DIR_DESTINO/configura_sistema.sh" ]; then
    echo -e "${VERDE}Sucesso! Chamando o construtor do sistema...${NC}"
    sleep 2
    bash "$DIR_DESTINO/configura_sistema.sh"
else
    echo -e "${VERMELHO}Erro: Ficheiro configura_sistema.sh não encontrado.${NC}"
    exit 1
fi
