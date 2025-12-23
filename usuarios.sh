#!/bin/bash

# --- CONFIGURAÇÕES INICIAIS ---
ORIGEM_ROOT="/root/.ssh/authorized_keys"

############################ FUNÇÕES ############################

function cadastrar_user {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[31mPor favor execute como sudo!\033[0m"
        sleep 2
        return # Volta para o menu sem fechar tudo
    fi

    echo "======================================"
    echo "    CADASTRO DE USUÁRIOS              "
    echo "======================================"
    read -p "Digite o nome do novo usuário: " NOME_USUARIO
    
    if [ -z "$NOME_USUARIO" ]; then return; fi

    sudo useradd -G sudo -m "$NOME_USUARIO" -s /bin/bash
    sudo mkdir -p "/home/$NOME_USUARIO/.ssh"

    if [ -f "$ORIGEM_ROOT" ]; then
        sudo cp "$ORIGEM_ROOT" "/home/$NOME_USUARIO/.ssh/authorized_keys"
        echo "✅ Chaves copiadas de /root"
    else
        echo "⚠️  Criando arquivo de chaves vazio."
        sudo touch "/home/$NOME_USUARIO/.ssh/authorized_keys"
    fi

    sudo chown -R "$NOME_USUARIO:$NOME_USUARIO" "/home/$NOME_USUARIO/.ssh"
    sudo chmod 700 "/home/$NOME_USUARIO/.ssh"
    sudo chmod 600 "/home/$NOME_USUARIO/.ssh/authorized_keys"
    
    sudo mkdir -p "/home/$NOME_USUARIO/transfer"
    sudo passwd "$NOME_USUARIO"

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
                echo "Usuário comum criado."
                break
                ;;
            *) echo -e "\033[31mOpção inválida!\033[0m" ;;
        esac
    done

    echo "Baixando scripts de gerenciamento..."
    sudo wget -P "/home/$NOME_USUARIO" https://github.com/jutair/configdebian/archive/refs/heads/main.zip
    sudo unzip "/home/$NOME_USUARIO/main.zip" -d "/home/$NOME_USUARIO"
    
    echo "Processo concluído!"
    sleep 2
    # REMOVIDO: gerencia_user (o loop do menu já vai cuidar disso)
}

function remove_user {
    clear
    LIST=$(ls /home)
    echo "======================================"
    echo "    USUÁRIOS CADASTRADOS:             "
    echo "$LIST"
    echo "======================================"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[31mErro: Requer privilégios root!\033[0m"
        sleep 2
        return
    fi

    read -p "Digite o nome do usuário a ser removido: " username
    if [ -z "$username" ]; then return; fi

    if id "$username" &>/dev/null; then
        echo "Removendo '$username'..."
        sudo userdel -r "$username"
        if [ $? -eq 0 ]; then
            echo "✅ Usuário removido."
        else
            echo "❌ Erro na remoção."
        fi
    else
        echo "❌ Usuário não encontrado."
    fi
    sleep 2
}

function promover_root {
    clear
    LIST=$(ls /home)
    echo "USUÁRIOS: $LIST"
    read -p "Nome do usuário para ser root: " username
    if id "$username" &>/dev/null; then
        sudo usermod -aG sudo "$username"
        echo "✅ Privilégios concedidos."
    else
        echo "❌ Usuário inexistente."
    fi
    sleep 2
}

function altera_senha {
    clear
    LIST=$(ls /home)
    echo "USUÁRIOS: $LIST"
    read -p "Nome do usuário: " username
    if id "$username" &>/dev/null; then
        sudo passwd "$username"
    else
        echo "❌ Usuário inexistente."
    fi
    sleep 2
}

######################## MENU PRINCIPAL ########################

function gerencia_user {
    while true; do
        clear
        CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
        LIST_USERS=$(ls /home | xargs) # Lista em linha única para o cabeçalho
        
        echo "==============================================================="
        echo "            GERENCIAMENTO DE USUÁRIOS                          "
        echo "==============================================================="
        echo "SISTEMA: $LIST_USERS"
        echo "VOCÊ ESTÁ LOGADO COMO: $CURRENRT"
        echo "==============================================================="
        echo ""
        echo "[1] Cadastrar Usuário      [4] Promover a Root"
        echo "[2] Remover Usuário        [5] Voltar ao Menu Principal"
        echo "[3] Alterar Senha          [9] Sair do Sistema"
        echo ""
        
        read -n 1 -p "Digite a opção desejada: " OPCAO
        echo ""

        case $OPCAO in
            1) cadastrar_user ;;
            2) remove_user ;;
            3) altera_senha ;;
            4) promover_root ;;
            5) 
                echo "Voltando..."
                exec ./menu.sh # SUBSTITUI o script atual pelo menu principal
                ;;
            9)
                clear
                echo "Encerrando tudo..."
                sleep 1
                # MATA A SESSÃO INTEIRA (Impede o retorno para scripts pais)
                kill -9 $(ps -o sess= -p $$)
                ;;
            *)
                echo -e "\033[31mOpção inválida!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Inicia a função
gerencia_user
