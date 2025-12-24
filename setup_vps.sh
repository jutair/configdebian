#!/bin/bash
# setup_vps.sh - Setup completo da VPS com menu automático e usuários SSH
set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root"
    exit 1
fi

echo "🔧 Iniciando setup da VPS..."

# 1️⃣ Instala dependências básicas
apt-get update
apt-get install -y wget unzip curl sudo

# 2️⃣ Limpeza de instalações anteriores
rm -rf /opt/configdebian
rm -rf /tmp/configdebian-main*
rm -f /tmp/main.zip

# 3️⃣ Baixa repositório
echo "📥 Baixando repositório configdebian..."
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# 4️⃣ Extrai e move para /opt/configdebian
echo "📂 Extraindo arquivos..."
unzip -q -o /tmp/main.zip -d /tmp/
mkdir -p /opt/configdebian
mv /tmp/configdebian-main/* /opt/configdebian/
chmod +x /opt/configdebian/*.sh
rm -f /tmp/main.zip

# 5️⃣ Executa o configura_sistema.sh diretamente do repositório
CONFIG_SCRIPT="/opt/configdebian/configura_sistema.sh"

if [ ! -f "$CONFIG_SCRIPT" ]; then
    echo "❌ Erro: configura_sistema.sh não encontrado em /opt/configdebian"
    exit 1
fi

echo "⚙️ Executando configura_sistema.sh..."
bash "$CONFIG_SCRIPT"

echo "✅ Setup VPS finalizado!"
echo "➡ Faça login com jutair ou guest via chave SSH do root. O menu iniciará automaticamente."
