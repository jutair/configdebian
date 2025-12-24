#!/bin/bash
# update_sistema.sh - Atualizador Global em /opt/configdebian
# Baixa o script do Angristan

AZUL='\033[0;34m'
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- CAMINHO GLOBAL ---
DESTINO="/opt/configdebian"

echo -e "${AZUL}===============================================================${NC}"
echo -e "              ATUALIZAÇÃO GERAL DO SISTEMA"
echo -e "${AZUL}===============================================================${NC}"

# 1. ATUALIZAÇÃO DO LINUX
echo -e "${AZUL}[1/2]${NC} Atualizando pacotes do sistema (Apt)..."
sudo apt update && sudo apt upgrade -y

# 2. ATUALIZAÇÃO DOS SCRIPTS NO DIRETÓRIO GLOBAL
echo -e "\n${AZUL}[2/2]${NC} Verificando atualizações no GitHub..."

TEMP_ZIP="/tmp/main.zip"
TEMP_EXTRACT="/tmp/configdebian-update"

# Baixa versão mais recente do repositório configdebian
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O "$TEMP_ZIP"

if [ -f "$TEMP_ZIP" ]; then
    mkdir -p "$TEMP_EXTRACT"
    unzip -o "$TEMP_ZIP" -d "$TEMP_EXTRACT" > /dev/null

    cp -r "$TEMP_EXTRACT/configdebian-main/"* "$DESTINO/"

    rm -rf "$TEMP_EXTRACT" "$TEMP_ZIP"

    echo -e "${VERDE}✔ Scripts configdebian atualizados com sucesso!${NC}"
else
    echo -e "${VERMELHO}✘ Falha ao conectar com o GitHub para configdebian.${NC}"
fi

# Baixa o openvpn-install.sh
OVPN_SCRIPT="$DESTINO/openvpn-install.sh"
wget -q https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh -O "$OVPN_SCRIPT"

if [ -f "$OVPN_SCRIPT" ]; then
    chmod +x "$OVPN_SCRIPT"
    echo -e "${VERDE}✔ openvpn-install.sh atualizado com sucesso!${NC}"
else
    echo -e "${VERMELHO}✘ Falha ao baixar openvpn-install.sh.${NC}"
fi

# Ajusta permissões de todos os scripts em /opt/configdebian
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo -e "${AZUL}===============================================================${NC}"
read -p " Atualização concluída. Pressione ENTER para reiniciar o menu..." dummy

# Reinicia o menu
exec bash "$DESTINO/menu.sh"
