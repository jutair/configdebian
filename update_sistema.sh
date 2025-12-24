#!/bin/bash
# update_sistema.sh - Atualizador Global em /opt

AZUL='\033[0;34m'
VERDE='\033[0;32m'
NC='\033[0m'

# --- DEFINIÇÃO DO CAMINHO GLOBAL ---
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

# Descarrega a versão mais recente
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O $TEMP_ZIP

if [ -f $TEMP_ZIP ]; then
    # Extrai para uma pasta temporária primeiro
    mkdir -p $TEMP_EXTRACT
    unzip -o $TEMP_ZIP -d $TEMP_EXTRACT > /dev/null
    
    # Move os novos ficheiros para a pasta de produção (/opt/configdebian)
    # Nota: O zip do github vem com uma pasta dentro 'configdebian-main'
    cp -r $TEMP_EXTRACT/configdebian-main/* "$DESTINO/"
    
    # Limpa temporários
    rm -rf $TEMP_EXTRACT $TEMP_ZIP
    
    # Garante permissões na pasta global
    chown -R root:sudo "$DESTINO"
    chmod -R 775 "$DESTINO"
    chmod +x "$DESTINO"/*.sh
    
    echo -e "${VERDE}✔ Scripts em $DESTINO atualizados com sucesso!${NC}"
else
    echo -e "${VERMELHO}✘ Falha ao conectar com o GitHub.${NC}"
fi

echo -e "${AZUL}===============================================================${NC}"
read -p " Atualização concluída. Pressione ENTER para reiniciar o menu..." dummy

# Reinicia o menu usando o caminho global
exec bash "$DESTINO/menu.sh"
