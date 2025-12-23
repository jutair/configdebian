#!/bin/bash

# --- CONFIGURAÇÃO DE AMBIENTE ---
# Detecta o usuário atual para navegação
CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)

############################ FUNÇÕES ############################

function cadastrar_user {
    clear
    # Verifica se o script foi executado como root
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[31mPor favor, execute este script como sudo!\033[0m"
        sleep 2
        return
    fi

    echo "======================================"
    echo "      CADASTRO DE NOVOS USUÁRIOS      "
    echo "======================================"
    
    read -p "Digite o nome do novo usuário: " NOME_USUARIO

    # 1. Cria o usuário com a home e shell padrão
    sudo useradd -m -s /bin/bash "$NOME_USUARIO"
    
    # 2. Configuração do diretório SSH e chaves
    HOME_USER="/home/$NOME_USUARIO"
    sudo mkdir -p "$HOME_USER/.ssh"
    
    if [ -f /root/.ssh/authorized_keys ]; then
        sudo cp /root/.ssh/authorized_keys "$HOME_USER/.ssh/authorized_keys"
        echo "✅ Chaves copiadas com sucesso de /root"
    else
        echo "⚠️  Aviso: /root/.ssh/authorized_keys não existe. Criando arquivo vazio."
        sudo touch "$HOME_USER/.ssh/authorized_keys"
    fi

    # 3. CRIAÇÃO DAS PASTAS PADRÃO (O que você solicitou)
    echo "Configurando pastas Backup, clientes_ovp e transfer..."
    sudo mkdir -p "$HOME_USER/Backup"
    sudo mkdir -p "$HOME_USER/clientes_ovp"
    sudo mkdir -p "$HOME_USER/transfer"

    # 4. BACKUP INICIAL DE CONFIGURAÇÕES PARA O NOVO USUÁRIO
    [ -f /etc/ssh/sshd_config ] && sudo cp /etc/ssh/sshd_config "$HOME_USER/Backup/sshd_config.bak"
    [ -f /etc/samba/smb.conf ] && sudo cp /etc/samba/smb.conf "$HOME_USER/Backup/smb.conf.bak"

    # 5. DOWNLOAD DOS SCRIPTS DO REPOSITÓRIO
    REPO_URL="https://github.com/jutair/configdebian/archive/refs/heads/main.zip"
    echo "Baixando scripts de gerenciamento para: $HOME_USER"
    sudo wget -qO "$HOME_USER/main.zip" "$REPO_URL"
    sudo unzip -qo "$HOME_USER/main.zip" -d "$HOME_USER/"
    sudo rm "$HOME_USER/main.zip"

    # 6. AJUSTE DE PERMISSÕES E DONO (CRÍTICO)
    sudo chown -R "$NOME_USUARIO:$NOME_USUARIO" "$HOME_USER"
    sudo chmod 700 "$HOME_USER/.ssh"
    sudo chmod 600 "$HOME_USER/.ssh/authorized_keys"
    sudo chmod -R +x "$HOME_USER/configdebian-main"/*.sh

    # 7. DEFINIÇÃO DE SENHA
    sudo passwd "$NOME_USUARIO"

    # 8. PERMISSÃO SUDO (OPCIONAL)
    while true; do
        read -n 1 -p "Deseja promover o usuário $NOME_USUARIO a root? [s/n]: " USEROOT
        echo ""
        case $USEROOT in
            [sS])
                sudo usermod -aG sudo "$NOME_USUARIO"
                echo "Usuário $NOME_USUARIO promovido ao grupo sudo!"
                break
                ;;
            [nN])
                echo "O usuário $NOME_USUARIO não terá privilégios root."
                # Adiciona permissão apenas para rodar o menu via sudo (limitação de segurança)
                echo "$NOME_USUARIO ALL=(ALL) NOPASSWD: /home/$NOME_USUARIO/configdebian-main/*.sh" | sudo tee -a /etc/sudoers > /dev/null
                break
                ;;
            *)
                echo -e "\033[31mOpção inválida!\033[0m Digite 's' ou 'n'."
                ;;
        esac
    done

    echo "✅ Processo concluído com sucesso para $NOME_USUARIO!"
    sleep 2
}

function remove_user {
    clear
    LIST=$(ls /home)
    echo "======================================"
    echo "        USUÁRIOS CADASTRADOS:         "
    echo "$LIST"
    echo "======================================"
    read -p "Digite o nome do usuário a ser removido: " username

    if id "$username" &>/dev/null; then
        # Proteção para não remover a si mesmo ou root
        if [ "$username" == "root" ] || [ "$username" == "$CURRENRT" ]; then
            echo -e "\033[31mErro: Você não pode remover o usuário logado ou o root!\033[0m"
            sleep 2
            return
        fi
        sudo userdel -r "$username"
        echo "Usuário '$username' removido com sucesso."
    else
        echo -e "\033[31mUsuário '$username' não encontrado!\033[0m"
    fi
    sleep 2
}

function promover_root {
    clear
    LIST=$(ls /home)
    echo "======================================"
    echo "        USUÁRIOS CADASTRADOS:         "
    echo "$LIST"
    echo "======================================"
    read -p "Digite o nome do usuário a ser promovido: " username
    if id "$username" &>/dev/null; then
        sudo usermod -aG sudo "$username"
        echo "Agora o usuário '$username' tem privilégio root."
    else
        echo -e "\033[31mUsuário não encontrado!\033[0m"
    fi
    sleep 2
}

function altera_senha {
    clear
    LIST=$(ls /home)
    echo "======================================"
    echo "        USUÁRIOS CADASTRADOS:         "
    echo "$LIST"
    echo "======================================"
    read -p "Digite o usuário para alterar a senha: " username
    if id "$username" &>/dev/null; then
        sudo passwd "$username"
    else
        echo -e "\033[31mUsuário não encontrado!\033[0m"
    fi
    sleep 2
}

############################ MENU PRINCIPAL ############################

function gerencia_user {
    while true; do
        clear
        CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
        LIST=$(ls /home)
        echo "======================================"
        echo "         GERENCIAR USUÁRIOS:          "
        echo "$LIST"
        echo "======================================"
        echo "Seu usuário: $CURRENRT"
        echo ""
        echo "[1] Cadastrar Novo"
        echo "[2] Remover Usuário"
        echo "[3] Alterar Senha"
        echo "[4] Promover a Root"
        echo "[5] Retornar ao Menu Principal"
        echo ""
        read -n 1 -p "Digite a opção desejada: " OPCAO
        echo ""
        case $OPCAO in
            1) cadastrar_user ;;
            2) remove_user ;;
            3) altera_senha ;;
            4) promover_root ;;
            5) 
                cd "/home/$CURRENRT/configdebian-main/" 2>/dev/null || cd "$HOME/configdebian-main/"
                exec sudo -E bash ./menu.sh
                ;;
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}

gerencia_user
