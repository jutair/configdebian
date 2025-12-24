#!/bin/bash
# configura_sistema.sh - CONFIGURADOR FINAL (Correção definitiva de login e menu)

DESTINO="/opt/configdebian"

# 1. Instalação de pacotes essenciais
apt-get update && apt-get install -y \
    vnstat ufw fail2ban openvpn samba speedtest-cli bc sudo

# 2. Configuração de Usuários
for USERNAME in "jutair" "guest"; do
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Senha123" | chpasswd
        usermod -aG sudo "$USERNAME"

        mkdir -p /home/$USERNAME/{Backup,clientes_ovp,transfer}

        # Copia chave SSH do root (se existir)
        if [ -f "/root/.ssh/authorized_keys" ]; then
            mkdir -p /home/$USERNAME/.ssh
            cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
            chmod 700 /home/$USERNAME/.ssh
            chmod 600 /home/$USERNAME/.ssh/authorized_keys
            chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
        fi
    fi

    # ------------------------------------------------------------------
    # LIMPEZA TOTAL DE ARQUIVOS DE LOGIN (remove lixo antigo)
    # ------------------------------------------------------------------
    rm -f /home/$USERNAME/.bashrc
    rm -f /home/$USERNAME/.profile
    rm -f /home/$USERNAME/.bash_login
    rm -f /home/$USERNAME/.bash_logout

    # ------------------------------------------------------------------
    # CRIA .bashrc CONTROLADO (entra direto no menu)
    # ------------------------------------------------------------------
    cat <<EOF > /home/$USERNAME/.bashrc
# ~/.bashrc - gerenciado automaticamente pelo configdebian

# Não executa em shell não interativo
[[ \$- != *i* ]] && return

# Proteção contra loop
if [ -z "\$MENU_LOADED" ]; then
    export MENU_LOADED=1
    sudo -E bash $DESTINO/menu.sh
fi
EOF

    chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc
    chmod 644 /home/$USERNAME/.bashrc
    chown -R $USERNAME:$USERNAME /home/$USERNAME
done

# 3. Permissão de sudo sem senha (necessário para o menu)
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-configdebian
chmod 440 /etc/sudoers.d/90-configdebian

# 4. Permissões finais da pasta global
chown -R root:sudo "$DESTINO"
chmod -R 775 "$DESTINO"
chmod +x "$DESTINO"/*.sh

echo "Configuração finalizada com sucesso!"
