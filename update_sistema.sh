#!/bin/bash
# update_sistema.sh - Atualizador Global em /opt/configdebian
# Atualizado: 24-12-2025

set -e

# --- CORES ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- CAMINHO DE DESTINO ---
DESTINO="/opt/configdebian"

echo -e "${AZUL}===============================================================${NC}"
echo -e "              ATUALIZAÇÃO GERAL DO SISTEMA"
echo -e "${AZUL}===============================================================${NC}"

# 1. ATUALIZAÇÃO DO LINUX
echo -e "${AZUL}[1/2]${NC} Atualizando pacotes do sistema (Apt)..."
sudo apt update && sudo apt upgrade -y

# 2. ATUALIZAÇÃO DOS SCRIPTS NO DIRETÓRIO GLOBAL
echo -e "\n${AZUL}[2/2]${NC} Verificando atualizações no GitHub..."

TEMP_ZIP="/tmp/configdebian-main.zip"
TEMP_EXTRACT="/tmp/configdebian-update"

# Baixa a versão mais recente do GitHub
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O $TEMP_ZIP

if [ -f "$TEMP_ZIP" ]; then
    mkdir -p "$TEMP_EXTRACT"
    unzip -o "$TEMP_ZIP" -d "$TEMP_EXTRACT" > /dev/null
    
    # Copia scripts para o diretório de produção
    cp -r "$TEMP_EXTRACT/configdebian-main/"* "$DESTINO/"
    
    # Baixa também o openvpn-install.sh do Angristan
    wget -q https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh -O "$DESTINO/openvpn-install.sh"
    
    # Ajusta permissões
    chown -R root:sudo "$DESTINO"
    chmod -R 775 "$DESTINO"
    chmod +x "$DESTINO"/*.sh
    
    # Limpeza
    rm -rf "$TEMP_EXTRACT" "$TEMP_ZIP"
    
    echo -e "${VERDE}✔ Scripts em $DESTINO atualizados com sucesso!${NC}"
else
    echo -e "${VERMELHO}✘ Falha ao conectar com o GitHub.${NC}"
fi

echo -e "${AZUL}===============================================================${NC}"
read -p " Atualização concluída. Pressione ENTER para reiniciar o menu..." dummy

# Reinicia o menu
exec bash "$DESTINO/menu.sh"
