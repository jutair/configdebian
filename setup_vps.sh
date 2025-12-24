#!/bin/bash
# setup_vps.sh - O MAESTRO (RODA COMO ROOT)

# 1. Instala dependências iniciais
apt-get update && apt-get install -y wget unzip curl

# 2. Baixa o repositório
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip -O /tmp/main.zip

# 3. Limpa instalações antigas e extrai
rm -rf /opt/configdebian
unzip -o /tmp/main.zip -d /tmp/

# 4. MOVE PARA O LOCAL DEFINITIVO (Aqui evita o erro de 'No such file')
mkdir -p /opt/configdebian
cp -r /tmp/configdebian-main/* /opt/configdebian/

# 5. DÁ PERMISSÃO DE EXECUÇÃO
chmod +x /opt/configdebian/*.sh

# 6. CHAMA O CONFIGURADOR QUE ESTÁ DENTRO DE /OPT
bash /opt/configdebian/configura_sistema.sh

# 7. Limpa temporários
rm -rf /tmp/main.zip /tmp/configdebian-main
