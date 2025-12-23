#!/bin/bash
# setup_vps.sh - Instalador Automatizado

# 1. Verificar se o usuário é root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mErro: Por favor, execute como root (use sudo ./setup_vps.sh)\033[0m"
  exit 1
fi

# 2. Instalar dependências básicas caso não existam
echo "Verificando dependências (wget, unzip)..."
apt-get update -qq
apt-get install -y wget unzip > /dev/null 2>&1

# 3. Preparar diretório temporário
cd /tmp
echo "Baixando scripts do repositório..."
# O -O garante que o nome do arquivo seja exatamente main.zip
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O main.zip

# 4. Extração
if [ -f "main.zip" ]; then
    unzip -o main.zip > /dev/null
else
    echo "Erro ao baixar o arquivo do GitHub."
    exit 1
fi

# 5. Execução do configurador
if [ -f "configdebian-main/configura_sistema.sh" ]; then
    chmod +x configdebian-main/configura_sistema.sh
    echo "Iniciando configuração do sistema..."
    ./configdebian-main/configura_sistema.sh
else
    echo "Erro: configura_sistema.sh não encontrado dentro do zip."
    exit 1
fi

# 6. Autodestruição e Limpeza
echo "Limpando arquivos temporários..."
rm -rf /tmp/main.zip /tmp/configdebian-main
rm -- "$0"

echo "Instalação finalizada. Por favor, faça login com o usuário jutair."
