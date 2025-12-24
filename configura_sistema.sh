#!/bin/bash
# setup_vps.sh - Script inicial da VPS (root)

set -e

# 1️⃣ Verifica se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

echo "🔧 Iniciando setup da VPS..."

# 2️⃣ Instala dependências básicas
apt-get update
apt-get install -y wget unzip curl sudo

# 3️⃣ Limpa instalações anteriores
rm -rf /opt/configdebian
rm -rf /tmp/configdebian-main*
rm -f /tmp/main.zip

# 4️⃣ Baixa o repositório
echo "📥 Baixando repositório configdebian..."
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# 5️⃣ Extrai para /tmp
echo "📂 Extraindo arquivos..."
unzip -q -o /tmp/main.zip -d /tmp/

# 6️⃣ Move para /opt/configdebian
echo "📁 Movendo arquivos para /opt/configdebian..."
mkdir -p /opt/configdebian
mv /tmp/configdebian-main/* /opt/configdebian/
chmod +x /opt/configdebian/*.sh

# 7️⃣ Chama o configurador do sistema
if [ -f /opt/configdebian/configura_sistema.sh ]; then
    echo "⚙️ Executando configura_sistema.sh..."
    bash /opt/configdebian/configura_sistema.sh
else
    echo "❌ ERRO CRÍTICO: configura_sistema.sh não encontrado em /opt/configdebian"
    exit 1
fi

# 8️⃣ Limpeza final
rm -rf /tmp/main.zip /tmp/configdebian-main*

echo "✅ Setup VPS finalizado com sucesso!"
echo "➡ Faça login com os usuários criados para iniciar o menu automaticamente."
