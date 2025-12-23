#!/bin/bash
################################Função de redes########################
update_sistema() {
NOME_USUARIO=${SUDO_USER:-$(whoami)}
DESTINO="/home/$NOME_USUARIO/configdebian-main"

# Verifica se o script foi executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como sudo!\033[0m"
  exit 1
fi

############ Verifica se já existe o script update_sistema.sh na pasta home ############
ARQUIVOS=$(find "/home/${NOME_USUARIO}/update_sistema.sh" ! -path "$DESTINO/*" 2>/dev/null)

if [ -z "$ARQUIVOS" ]; then
    echo -e "Não foi encontrado script de atualização na pasta home!"
else
    echo "Removendo o script antigo da pasta home."
    sudo rm "/home/${NOME_USUARIO}/update_sistema.sh"
fi

#################################################################################
echo "=========================================================================="
echo "Baixando um novo script de atualização..."
echo "=========================================================================="
sudo wget -P "/home/${NOME_USUARIO}" "https://raw.githubusercontent.com/jutair/configdebian/refs/heads/main/update_sistema.sh"
sudo chmod +x "/home/${NOME_USUARIO}/update_sistema.sh"

sudo "/home/${NOME_USUARIO}/.update_sistema.sh"
}
###################Fim da função update sistema#################################
function gerencia_rede {
    ############Função testa velocidade############
    function testa_velocidade {
        clear
        echo "======================================"
        echo "        Velocidade da rede:            "
        echo "======================================"
        echo "Isto pode levar algum tempo!"
        echo "Aguarde, testando a conexão da VPS..."
        # Captura apenas os números usando grep e cut
        PING=$(speedtest-cli --simple | grep "Ping" | cut -d' ' -f2)
        DOWNLOAD=$(speedtest-cli --simple | grep "Download" | cut -d' ' -f2)
        UPLOAD=$(speedtest-cli --simple | grep "Upload" | cut -d' ' -f2)
        clear
        echo "Sua velocidade de Download é: $DOWNLOAD Mbps"
        echo "Sua velocidade de Upload é: $UPLOAD Mbps"
        echo "O seu ping é: $PING ms" # Corrigi aqui para exibir PING
        read -p "Pressione ENTER para voltar..." dummy
    }

    ############Função monitora placa de rede############
    function monitora_placa {
        clear
        INTERFACE=$(ip route | grep default | awk '{print $5}')
        echo "Monitorando a interface: $INTERFACE"
        echo "Pressione CTRL+C para parar."
        trap ':' INT
        vnstat -l -i "$INTERFACE"
        trap - INT
    }

    ###############Função relatório de consumo###########
    function relatorio_consumo {
        while true; do
            INTERFACE=$(ip route | grep default | awk '{print $5}')
            CURRENRT=${SUDO_USER:-$(whoami)}
            clear
            echo "======================================"
            echo "   Relatório de consumo de rede:      "
            echo "======================================"
            echo "Seu usuário: $CURRENRT"
            echo ""
            echo "[1] Anual"
            echo "[2] Mensal"
            echo "[3] Diário"
            echo "[4] Sair"
            echo ""
            read -n 1 -p "Digite a opção desejada: " OPCAO
            echo ""
            case $OPCAO in
                [1]) clear; vnstat -y -i "$INTERFACE"; read -p "Pressione ENTER..." dummy ;;
                [2]) clear; vnstat -m -i "$INTERFACE"; read -p "Pressione ENTER..." dummy ;;
                [3]) clear; vnstat -d -i "$INTERFACE"; read -p "Pressione ENTER..." dummy ;;
                [4]) break ;;
                *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
            esac
        done
    }

    # Loop principal da gerencia_rede
    while true; do
        CURRENRT=${SUDO_USER:-$(whoami)}
        IP_EXTERNO=$(curl -s ifconfig.me)
        clear
        echo "======================================"
        echo "           Gerenciar rede:            "
        # CORREÇÃO DA LINHA 98 ABAIXO (Aspas fechadas)
        echo "IP externo da rede: $IP_EXTERNO" 
        echo "======================================"
        echo "Seu usuário: $CURRENRT"
        echo ""
        echo "[1] Testar velocidade"
        echo "[2] Monitorar placa de rede"
        echo "[3] Ver relatório de consumo de rede"
        echo "[4] Voltar ao Menu Principal"
        echo ""
        read -n 1 -p "Digite a opção desejada: " OPCAO
        echo ""
        case $OPCAO in
            [1]) testa_velocidade ;;
            [2]) monitora_placa ;;
            [3]) relatorio_consumo ;;
            [4]) return ;; # Usa return para sair da função e voltar ao menu
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}

#########################################################
function menu {
    while true; do
        CURRENRT=${SUDO_USER:-$(whoami)}
        IP_EXTERNO=$(curl -s ifconfig.me)
        clear
        echo "========================================================="
        echo "                Menu principal:                          "
        echo "Ip externo da rede: $IP_EXTERNO"
        echo "Seu usuário: $CURRENRT"
        echo "========================================================="
        echo ""
        echo "[1] Gerenciar Sistema        [6] Gerenciar usuários"
        echo "[2] Gerenciar Rede           [7] Atualizar o sistema"
        echo "[3] Ver logs do sistema      [8] Gerenciar OpenVpn"
        echo "[5] Fazer Backup             [9] Sair"
        echo ""
        read -n 1 -p "Digite a opção desejada: " OPCAO
        echo ""
        case $OPCAO in
            [1]) echo "Em desenvolvimento..." ; sleep 1 ;;
            [2]) gerencia_rede ;;
            [6]) ./usuarios.sh ;;
            [7]) update_sistema ;;
            [8]) ./open_vpn_conf.sh ;;
            [9]) exit 0 ;;
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}

# Início do Script
menu
