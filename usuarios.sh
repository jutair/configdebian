#!/bin/bash
clear
ORIGEM="/home/jutair/.ssh/authorized_keys"
echo "======================================"
echo "    CADASTRO DE USUÁRIOS              "
echo "======================================"
# 1. Solicita a entrada de texto (palavra completa)
read -p "Digite o nome do novo usuário: " NOME_USUARIO
sudo useradd -G sudo -m $NOME_USUARIO -s /bin/bash
sudo mkdir -p "/home/$NOME_USUARIO/.ssh"
sudo cp "$ORIGEM" "/home/$NOME_USUARIO/.ssh/authorized_keys"
sudo mkdir -p "/home/$NOME_USUARIO/.ssh"
sudo chown -R "$NOME_USUARIO:$NOME_USUARIO" "/home/$NOME_USUARIO/.ssh"
sudo chmod 700 "/home/$NOME_USUARIO/.ssh"
sudo chmod 600 "/home/$NOME_USUARIO/.ssh/authorized_keys"
# 2. Solicita o toque de alguma tecla
read -n 1 -p "Deseja promover a usurário root? [s/n]: " USEROOT
echo ""
echo "Usurário $NOME_USUARIO criado!"
# Loop infinito que só para quando encontrar o 'break'
while true; do
    read -n 1 -p "Deseja promover o usuário $NOME_USUARIO a root? [s/n]: " USEROOT
    echo "" # Pula linha após o caractere

    case $USEROOT in
        [sS])
            sudo usermod -aG sudo "$NOME_USUARIO"
            echo "Usuário $NOME_USUARIO promovido ao grupo sudo (root)!"
            break # Sai do loop while
            ;;
        [nN])
            echo "O usuário $NOME_USUARIO não terá privilégios root."
            break # Sai do loop while
            ;;
        *)
            # Se digitar qualquer outra coisa (e, r, 5, etc)
            echo -e "\033[31mOpção inválida!\033[0m Por favor, digite apenas 's' para Sim ou 'n' para Não."
            ;;
    esac
done

echo "Processo concluído para o usuário $NOME_USUARIO!"
