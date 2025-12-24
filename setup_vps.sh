#!/bin/bash
# setup_vps.sh - O MAESTRO (RODA COMO ROOT)

# 1. Instala dependências
apt-get update && apt-get install -y wget unzip curl

# 2. Limpeza de instalações anteriores
rm -rf /opt/configdebian
rm -rf /tmp/configdebian*
rm -f /tmp/main.zip

# 3. Baixa o repositório
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# 4. Extrai
unzip -o /tmp/main.zip -d /tmp/

# 5. MOVE PARA /OPT (Usando coringa * para não errar o nome da pasta)
mkdir -p /opt/configdebian
# Entra na pasta extraída, seja qual for o nome, e move o conteúdo
cd /tmp/configdebian-*/ && cp -rf ./* /opt/configdebian/

# 6. DÁ PERMISSÃO DE EXECUÇÃO
chmod +x /opt/configdebian/*.sh

# 7. CHAMA O CONFIGURADOR USANDO CAMINHO ABSOLUTO
if [ -f /opt/configdebian/configura_sistema.sh ]; then
    bash /opt/configdebian/configura_sistema.sh
else
    echo "ERRO CRÍTICO: Arquivo configura_sistema.sh não encontrado em /opt/configdebian"
    exit 1
fi

# 8. Limpeza final
rm -rf /tmp/main.zip /tmp/configdebian*
