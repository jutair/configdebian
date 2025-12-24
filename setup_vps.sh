#!/bin/bash
# setup_vps.sh - Setup inicial da VPS (root)

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root"
    exit 1
fi

echo "🔧 Iniciando setup da VPS..."

# Instala dependências básicas
apt-get update
apt-get install -y wget unzip curl sudo

# Limpeza de instalações anteriores
rm -rf /opt/configdebian
rm -rf /tmp/configdebian-main*
rm -f /tmp/main.zip

# Baixa repositório
echo "📥 Baixando repositório configdebian..."
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# Extrai e move para /opt/configdebian
echo "📂 Extraindo arquivos..."
unzip -q -o /tmp/main.zip -d /tmp/
mkdir -p /opt/configdebian
mv /tmp/configdebian-main/* /opt/configdebian/
chmod +x /opt/configdebian/*.sh
rm -f /tmp/main.zip

# Chama o configurador do sistema
if [ -f /opt/configdebian/configura_sistema.sh ]; then
    echo "⚙️ Executando configura_sistema.sh..."
    bash /opt/configdebian/configura_sistema.sh
else
    echo "❌ configura_sistema.sh não encontrado em /opt/configdebian"
    exit 1
fi

echo "✅ Setup VPS finalizado!"
echo "➡ Faça login com os usuários criados (jutair/guest) para iniciar o menu automaticamente."
