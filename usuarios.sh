#!/bin/bash
clear
echo -e "\033[0m"
ORIGEM="/home/jutair/.ssh/authorized_keys"
############################Funções######################
###################################################################
function cadastrar_user {
clear
# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script somo sudo!"
  echo -e "\033[0m"
  exit 1
fi
ORIGEM="root/.ssh/authorized_keys"
echo "======================================"
echo "    CADASTRO DE USUÁRIOS              "
echo "======================================"
# 1. Solicita a entrada de texto (palavra completa)
read -p "Digite o nome do novo usuário: " NOME_USUARIO
sudo useradd -G sudo -m $NOME_USUARIO -s /bin/bash
sudo mkdir -p "/home/$NOME_USUARIO/.ssh"
# 3. Tenta copiar a chave do root, mas verifica se ela existe primeiro
if [ -f /root/.ssh/authorized_keys ]; then
    sudo cp /root/.ssh/authorized_keys /home/jutair/.ssh/
    echo "✅ Chaves copiadas com sucesso de /root"
else
    echo "⚠️  Aviso: /root/.ssh/authorized_keys não existe. Criando arquivo vazio."
    sudo touch /home/$NOME_USUARIO/.ssh/authorized_keys
fi
sudo cp "$ORIGEM" "/home/$NOME_USUARIO/.ssh/authorized_keys"
sudo mkdir -p "/home/$NOME_USUARIO/.ssh"
sudo chown -R "$NOME_USUARIO:$NOME_USUARIO" "/home/$NOME_USUARIO/.ssh"
sudo chmod 700 "/home/$NOME_USUARIO/.ssh"
sudo chmod 600 "/home/$NOME_USUARIO/.ssh/authorized_keys"
#####################Cria a pasta transfer para o usuário################
sudo mkdir -p "/home/$NOME_USUARIO/transfer"
sudo passwd $NOME_USUARIO
# 2. Solicita o toque de alguma tecla
echo "Usurário $NOME_USUARIO criado!"
# Loop infinito que só para quando encontrar o 'break'
while true; do
    read -n 1 -p "Deseja promover o usuário $NOME_USUARIO a root? [s/n]: " USEROOT
    echo "" # Pula linha após o caractere

    case $USEROOT in
        [sS])
            sudo usermod -aG sudo "$NOME_USUARIO"
            clear
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
echo "Baixando os scripts de gerenciamento do sistema na pasta /home/${NOME_USUARIO}/configdebian-main"
sudo wget -P /home/${NOME_USUARIO} https://github.com/jutair/configdebian/archive/refs/heads/main.zip
sudo unzip /home/${NOME_USUARIO}/main.zip -d /home/$NOME_USUARIO
echo "Processo concluído para o usuário $NOME_USUARIO!"
echo -e "\033[0m"
sleep 2
gerencia_user
}
################################################################
function remove_user {
clear
echo "======================================"
echo "    USUÁRIOS CADASTRADOS:              "
echo "$LIST"
echo "======================================"
echo ""
LIST=$(ls /home)
# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script somo sudo!"
  sleep 2
  echo -e "\033[0m"
  gerencia_user
  #exit 1
fi

# Pede o nome do usuário a ser removido
read -p "Digite o nome do usuário a ser removido: " username

# Verifica se o usuário existe
if id "$username" &>/dev/null; then
  echo "Removendo usuário '$username' e seu diretório home..."
  # Comando para remover usuário e diretório home
  # Use 'userdel -r' ou 'deluser --remove-home'
  userdel -r "$username"
  # Ou: deluser --remove-home "$username"

  if [ $? -eq 0 ]; then
    clear
    echo "Usuário '$username' removido com sucesso."
    sleep 2
    gerencia_user
  else
    echo -e "\033[31mErro ao remover o usuário '$username'."
    sleep 2
    echo -e "\033[0m"
    gerencia_user
  fi
else
  echo -e "\033[31mUsuário '$username' não encontrado!."
  sleep 2
  echo -e "\033[0m"
  gerencia_user
fi
}
################################################################
function promover_root {
clear
echo "======================================"
echo "    USUÁRIOS CADASTRADOS:              "
echo "$LIST"
echo "======================================"
echo ""
LIST=$(ls /home)
# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script somo sudo!"
  echo -e "\033[0m"
  exit 1
fi

# Pede o nome do usuário a ser removido
read -p "Digite o nome do usuário a ser promovido a root: " username
clear

# Verifica se o usuário existe
if id "$username" &>/dev/null; then
  sudo usermod -aG sudo "$username"
  if [ $? -eq 0 ]; then
    clear
    echo "Agora o usuário '$username' tem privilégio root."
    sleep 2
    clear
  else
    echo -e "\033[31mErro ao promover o usuário '$username'."
    echo -e "\033[0m"
  fi
else
  echo -e "\033[31mUsuário '$username' não encontrado!."
  echo -e "\033[0m"
fi
}
##################################################################
function altera_senha {
clear
echo "======================================"
echo "    USUÁRIOS CADASTRADOS:              "
echo "$LIST"
echo "======================================"
echo ""
LIST=$(ls /home)
# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script somo sudo!"
  echo -e "\033[0m"
  exit 1
fi

# Pede o nome do usuário a ser removido
read -p "Digite o nome do usuário para alterar a senha: " username
clear

# Verifica se o usuário existe
if id "$username" &>/dev/null; then
  sudo passwd "$username"
  if [ $? -eq 0 ]; then
    clear
    echo "Foi alterada a senha para o usuário '$username'"
    sleep 2
    clear
  else
    echo -e "\033[31mErro ao trocar a senha do usuário '$username'."
    echo -e "\033[0m"
  fi
else
  echo -e "\033[31mUsuário '$username' não encontrado!."
  echo -e "\033[0m"
fi
}
############################Fim das funções######################
function gerencia_user {
clear
while true; do
CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
LIST=$(ls /home)
echo "======================================"
echo "    GERENCIAR USUÁRIOS:              "
echo "$LIST"
echo "======================================"
echo "Seu usuário: $CURRENRT"
echo ""
echo "[1] Casdastrar"
echo "[2] Remover"
echo "[3] Alterar senha"
echo "[4] Promover a usuário root"
echo "[5] Sair"
read -n 1 -p "Digite a opção desejada: " OPCAO
echo ""
case $OPCAO in
        [1])
            echo ""
            echo "echo "Você digitou a opção [1]""
            #sleep 1
            cadastrar_user
            ;;
        [2])
            echo ""
            echo "Você digitou a opção [2]"
            #sleep 1
            remove_user
            ;;
        [3])
            echo ""
            echo "Você digitou a opção [3]"
            #sleep 1
            altera_senha
            #break # Sai do loop while
            ;;
        [4])
            echo ""
            echo "Você digitou a opção [4]"
            #sleep 1
            promover_root
            ;;
        [5])
            echo ""
            echo "Você digitou a opção [5]"
            echo "Saindo..."
            sleep 1
            clear
            ./menu.sh
            #exit
            ;;
        *)
            # Se digitar qualquer outra coisa (e, r, 5, etc)
            clear
            echo -e "\033[31mOpção inválida!\033[0m Por favor, digite apenas 's' para Sim ou 'n' para Não."
            echo ""
            ;;
    esac
done

echo "Processo concluído para o usuário $NOME_USUARIO!"
clear
}
gerencia_user ###Chama a função principal!
