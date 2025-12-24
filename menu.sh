#!/bin/bash
# configura_sistema.sh
# Configuração inicial do sistema + menu automático no login SSH

set -e

### VARIÁVEIS ###
USERNAME="jutair"
USER_HOME="/home/$USERNAME"
DIR_SCRIPTS="$USER_HOME/configdebian-main"
MENU_SCRIPT="$DIR_SCRIPTS/menu.sh"

echo "🔧 Iniciando configuração do sistema..."

### 1️⃣ GARANTE QUE O SCRIPT RODE COMO ROOT ###
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root."
    exit 1
fi

### 2️⃣ CRIA USUÁRIO SE NÃO EXISTIR ###
if ! id "$USERNAME" &>/dev/null; then
    echo "👤 Criando usuário $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    passwd "$USERNAME"
else
    echo "👤 Usuário $USERNAME já existe."
fi

### 3️⃣ INSTALA DEPENDÊNCIAS BÁSICAS ###
echo "📦 Instalando pacotes essenciais..."
apt update
apt install -y sudo curl vnstat

### 4️⃣ CONFIGURA SUDO SEM SENHA (OPCIONAL) ###
echo "🔐 Configurando sudo sem senha para $USERNAME..."
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

### 5️⃣ GARANTE DIRETÓRIO DE SCRIPTS ###
mkdir -p "$DIR_SCRIPTS"
chown -R "$USERNAME:$USERNAME" "$DIR_SCRIPTS"

### 6️⃣ CONFIGURA .bashrc PARA CHAMAR O MENU ###
echo "🧠 Configurando .bashrc..."

cat <<'EOF' > "$USER_HOME/.bashrc"
# ~/.bashrc - gerenciado pelo configura_sistema.sh

# Sai se não for shell interativo
[[ $- != *i* ]] && return

# Evita loop infinito
if [ -z "$MENU_INICIADO" ]; then
    export MENU_INICIADO=1

    MENU="$HOME/configdebian-main/menu.sh"
    if [ -x "$MENU" ]; then
        clear
        sudo -E bash "$MENU"
        exit
    else
        echo "⚠ Menu não encontrado ou sem permissão."
    fi
fi
EOF

### 7️⃣ CONFIGURA .profile (ESSENCIAL PARA SSH) ###
echo "🔑 Configurando .profile..."

cat <<'EOF' > "$USER_HOME/.profile"
# ~/.profile - gerenciado pelo configura_sistema.sh

# Carrega bashrc no login SSH
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

### 8️⃣ PERMISSÕES CORRETAS ###
chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" "$USER_HOME/.profile"
chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.profile"

### 9️⃣ GARANTE PERMISSÃO DE EXECUÇÃO DO MENU ###
if [ -f "$MENU_SCRIPT" ]; then
    chmod +x "$MENU_SCRIPT"
    chown "$USERNAME:$USERNAME" "$MENU_SCRIPT"
else
    echo "⚠ ATENÇÃO: menu.sh ainda não existe em $DIR_SCRIPTS"
fi

### 🔟 FINALIZA ###
echo "✅ Configuração concluída com sucesso!"
echo "➡ Ao logar via SSH com $USERNAME, o menu será iniciado automaticamente."
