#!/bin/bash
# setup_vps.sh - O Maestro (Root)

# 1. Limpeza e Dependências
apt-get update && apt-get install -y wget unzip curl

# 2. Baixar e Extrair
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip
unzip -o /tmp/main.zip -d /tmp/

# 3. CRIAR O DIRETÓRIO DESTINO (Crucial para evitar o erro de chmod)
mkdir -p /opt/configdebian

# 4. MOVER OS ARQUIVOS (Garante que os scripts existam antes do chmod)
cp -r /tmp/configdebian-main/* /opt/configdebian/

# 5. PERMISSÕES INICIAIS
chmod +x /opt/configdebian/*.sh

# 6. EXECUTAR O CONFIGURADOR (Agora ele vai encontrar a pasta /opt)
bash /opt/configdebian/configura_sistema.sh

# 7. Limpeza
rm -rf /tmp/main.zip /tmp/configdebian-main
