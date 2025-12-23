#!/bin/bash
################################Função de redes########################
function gerencia_rede {
############Função testa velocidade############
function testa_velocidade {
clear
echo "======================================"
echo "       Velocidade da rede:            "
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
echo "O seu ping é: $UPLOAD Mbps"
}
############Fim da função testa velocidade############
############Função monitora placa de rede############
function monitora_placa {
clear
# Detecta a interface de rede ativa que tem a rota padrão
INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "Monitorando a interface: $INTERFACE"
vnstat -l -i "$INTERFACE"
gerencia_rede
}
############Fim da função monitora placa de rede############
###############Função relatório de consumo###########
function relatorio_consumo {
clear
while true; do
INTERFACE=$(ip route | grep default | awk '{print $5}')
CURRENRT=${SUDO_USER:-$(whoami)}
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
        [1])
        clear
	echo "======================================"
	echo "         Consumo do ano:              "
	echo "======================================"
            CONSUMO=$(vnstat -y -i "$INTERFACE")
            echo "$CONSUMO"
            #sleep 1
            ;;
        [2])
        clear
	echo "======================================"
	echo "          Consumo do mês:             "
	echo "======================================"
            CONSUMO=$(vnstat -m -i "$INTERFACE")
            echo "$CONSUMO"
            ;;
        [3])
        clear
	echo "======================================"
	echo "           Consumo do dia:            "
	echo "======================================"
            CONSUMO=$(vnstat -d -i "$INTERFACE")
            echo "$CONSUMO"
            ;;
        [4])
            echo ""
            echo "Saindo..."
            sleep 1
            clear
            break
            ;;
        *)
            # Se digitar qualquer outra coisa (e, r, 5, etc)
            clear
            echo -e "\033[31mOpção inválida!\033[0m Por favor, digite apenas 's' para Sim ou 'n' para Não."
            echo ""
            ;;
    esac
done
}
#########Fim da função relatório de consumo##########
#####################################################
clear
while true; do
CURRENRT=${SUDO_USER:-$(whoami)}
echo "======================================"
echo "    Gerenciar rede:              "
echo "======================================"
echo "Seu usuário: $CURRENRT"
echo ""
echo "[1] Testar velocidade"
echo "[2] Monitorar placa de rede"
echo "[3] Ver relatório de consumo de rede"
echo "[4] Sair"
echo ""
read -n 1 -p "Digite a opção desejada: " OPCAO
echo ""
case $OPCAO in
        [1])
            echo ""
            testa_velocidade
            #sleep 1
            ;;
        [2])
            echo ""
            monitora_placa
            ;;
        [3])
            echo ""
            relatorio_consumo
            ;;
        [4])
            echo ""
            echo "Saindo..."
            sleep 1
            menu
            ;;
        *)
            # Se digitar qualquer outra coisa (e, r, 5, etc)
            clear
            echo -e "\033[31mOpção inválida!\033[0m Por favor, digite apenas 's' para Sim ou 'n' para Não."
            echo ""
            ;;
    esac
done

}
##############Fim da função rede#########################
#########################################################
function menu {
clear
while true; do
CURRENRT=${SUDO_USER:-$(whoami)}
echo "======================================"
echo "    Menu principal:              "
echo "======================================"
echo "Seu usuário: $CURRENRT"
echo ""
echo "[1] Ver desempenho		[6] Gerenciar usuários"
echo "[2] Gerenciar rede 		[7] Atualizar o sistema"
echo "[3] Ver logs do sistema		[8] Gerenciar OpenVpn"
echo "[5] Fazer Backup"					
echo ""
read -n 1 -p "Digite a opção desejada: " OPCAO
echo ""
case $OPCAO in
        [1])
            echo ""
            #sleep 1
            ;;
        [2])
            echo ""
            gerencia_rede
            #sleep 1
            ;;
        [3])
            echo ""
            #sleep 1
            #break # Sai do loop while
            ;;
        [4])
            echo ""
            #sleep 1
            ;;
        [5])
            echo ""
            #sleep 1
            ;;
        [6])
            ./usuarios.sh
            #sleep 1
            ;;
        [7])
            echo ""
            #sleep 1
            ;;
        [8])
            ./open_vpn_conf.sh
            #sleep 1
            ;;            
        [9])
            echo ""
            echo "Saindo..."
            sleep 1
            clear
            exit
            ;;
        *)
            # Se digitar qualquer outra coisa (e, r, 5, etc)
            clear
            echo -e "\033[31mOpção inválida!\033[0m Por favor, digite apenas 's' para Sim ou 'n' para Não."
            echo ""
            ;;
    esac
done
clear
}
clear
