#!/bin/bash
################################Função de redes########################
update_sistema() {
NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
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
cd /home/${NOME_USUARIO}/
sudo ./update_sistema.sh
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
        read -p "Pressione ENTER para voltar..." dummy
    }

    ###############Função relatório de consumo###########
    function relatorio_consumo {
        while true; do
            INTERFACE=$(ip route | grep default | awk '{print $5}')
            CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
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
        CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
        IP_EXTERNO=$(curl -4 -s ifconfig.me || curl -4 -s ident.me)
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
IP_EXTERNO=$(curl -4 -s ifconfig.me || curl -4 -s ident.me)
IP_INTERNO=$(hostname -I | awk '{print $1}')
CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
    while true; do
        #CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
        clear
        HORA_ATUAL=$(date '+%H:%M:%S')
        # Captura a data atual
        DATA_ATUAL=$(date '+%d/%m/%Y')
        echo "================================================================="
        echo "                    MENU PRINCIPAL                               "
        echo "Usuário:$CURRENRT"
        echo "================================================================="
        echo "DATA: $DATA_ATUAL                         HORA: $HORA_ATUAL (MANAUS)"
        echo "IP Interno: $IP_INTERNO | IP Externo: $IP_EXTERNO"
        echo "================================================================="
        echo "Versão do script: 22/12/2025-3:18:57"
        echo "================================================================="
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
            [9]) exit ;;
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}

# Início do Script
menu
