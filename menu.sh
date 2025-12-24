#!/bin/bash
# configura_sistema.sh - Versão de Caminhos Globais

DESTINO="/opt/configdebian"
# 1. Prepara a pasta global
rm -rf "$DESTINO"
mkdir -p "$DESTINO"
# Assume que você baixou o zip e ele extraiu para $HOME/configdebian-main
cp -r $HOME/configdebian-main/* "$DESTINO/"

# ... (parte de instalação de pacotes e criação de users continua igual) ...

# 4. CRIAÇÃO DE USUÁRIOS (Corrigindo o caminho do Bashrc)
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"
        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}
        
        # Injeção do Menu (Atenção ao caminho /opt)
        sed -i '/menu.sh/d' /home/$USERNAME/.bashrc
        echo "if [ -f $DESTINO/menu.sh ]; then" >> /home/$USERNAME/.bashrc
        echo "  sudo -E bash $DESTINO/menu.sh" >> /home/$USERNAME/.bashrc
        echo "fi" >> /home/$USERNAME/.bashrc
    fi
done

# 5. PERMISSÕES CRÍTICAS
# Garante que o grupo sudo possa ler e executar tudo em /opt/configdebian
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo "Configuração completa em $DESTINO"
