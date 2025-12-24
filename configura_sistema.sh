#!/bin/bash
# configura_sistema.sh - Versão CORRIGIDA de Caminhos

# 1. Localizar onde os scripts foram extraídos (Busca automática)
# Procura a pasta configdebian-main no diretório atual ou no root
ORIGEM=$(find /root /home -name "configdebian-main" -type d -print -quit)
DESTINO="/opt/configdebian"

if [ -z "$ORIGEM" ]; then
    echo "Erro: Pasta configdebian-main não encontrada em /root ou /home"
    exit 1
fi

echo "Origem encontrada em: $ORIGEM"

# 2. Prepara a pasta global /opt
rm -rf "$DESTINO"
mkdir -p "$DESTINO"
cp -r "$ORIGEM"/* "$DESTINO/"

# 3. Instalação de pacotes
apt-get update && apt-get install -y curl wget unzip vnstat ufw fail2ban openvpn samba speedtest-cli bc

# 4. CRIAÇÃO DE USUÁRIOS (jutair e guest)
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Copia a chave SSH do root para o usuário conseguir logar
        if [ -d "/root/.ssh" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
            chmod 700 /home/$USERNAME/.ssh
        fi

        # Injeção do Menu no login (CAMINHO ABSOLUTO)
        sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
        echo "if [ -f $DESTINO/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
    fi
done

# 5. PERMISSÕES FINAIS
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-vpn-users

echo "Configuração completa em $DESTINO"
