#!/bin/bash
function ver_consumo {
#!/bin/bash
STATUS_FILE="/var/log/openvpn/openvpn-status.log"

# Verifica se o ficheiro de log existe
if [ ! -f "$STATUS_FILE" ]; then
    echo "Erro: Ficheiro $STATUS_FILE não encontrado!"
    exit 1
fi
echo "==============================================================="
echo "             CONSUMO DE DADOS POR UTILIZADOR (Sessão Atual)"
echo "==============================================================="
# O printf ajuda a alinhar as colunas: %-15s (15 espaços à esquerda)
printf "%-15s %-12s %-12s %-12s\n" "UTILIZADOR" "RECEBIDO" "ENVIADO" "TOTAL"
echo "---------------------------------------------------------------"

# Processa o log
grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
    
    # Extração de colunas baseada no seu formato de vírgula
    USER=$(echo "$line" | cut -d',' -f2)
    RECV_B=$(echo "$line" | cut -d',' -f5)
    SENT_B=$(echo "$line" | cut -d',' -f6)

    # Validação para garantir que são números
    if [[ ! "$RECV_B" =~ ^[0-9]+$ ]]; then RECV_B=0; fi
    if [[ ! "$SENT_B" =~ ^[0-9]+$ ]]; then SENT_B=0; fi

    # Cálculo em Megabytes (MB) usando o bc
    RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc)
    SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc)
    TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc)

    # Imprime os dados formatados
    printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
done
echo "---------------------------------------------------------------"
}
####################Fim da função consumo usuário####################
###################Função Usuários online############################
function user_online {
#!/bin/bash
STATUS_FILE="/var/log/openvpn/openvpn-status.log"
echo "==============================================================="
echo "                USUÁRIOS CONECTADOS AGORA"
echo "==============================================================="
printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
echo "---------------------------------------------------------------"

# O grep busca linhas que começam com CLIENT_LIST
# O grep -v ignora o cabeçalho
grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
    
    # Extraindo colunas (ajustado para separador de vírgula)
    USER=$(echo "$line" | cut -d',' -f2)
    IP_REAL=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1) # Remove a porta
    IP_VPN=$(echo "$line" | cut -d',' -f4)
    DESDE=$(echo "$line" | cut -d',' -f8 | cut -d' ' -f2,3) # Pega apenas hora/data

    # Formata a saída em colunas alinhadas
    printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_REAL" "$IP_VPN" "$DESDE"
done
echo "---------------------------------------------------------------"
echo "Total de conexões: $(grep -c "^CLIENT_LIST" "$STATUS_FILE" | awk '{print $1-1}')"
}
#################Fim da função usuários online###################
function user_cosumo {
#!/bin/bash

STATUS_FILE="/var/log/openvpn/openvpn-status.log"

# Verifica se o ficheiro de log existe
if [ ! -f "$STATUS_FILE" ]; then
    echo "Erro: Ficheiro $STATUS_FILE não encontrado!"
    exit 1
fi

echo "==============================================================="
echo "             CONSUMO DE DADOS POR UTILIZADOR (Sessão Atual)"
echo "==============================================================="
# O printf ajuda a alinhar as colunas: %-15s (15 espaços à esquerda)
printf "%-15s %-12s %-12s %-12s\n" "UTILIZADOR" "RECEBIDO" "ENVIADO" "TOTAL"
echo "---------------------------------------------------------------"

# Processa o log
grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
    
    # Extração de colunas baseada no seu formato de vírgula
    USER=$(echo "$line" | cut -d',' -f2)
    RECV_B=$(echo "$line" | cut -d',' -f5)
    SENT_B=$(echo "$line" | cut -d',' -f6)

    # Validação para garantir que são números
    if [[ ! "$RECV_B" =~ ^[0-9]+$ ]]; then RECV_B=0; fi
    if [[ ! "$SENT_B" =~ ^[0-9]+$ ]]; then SENT_B=0; fi

    # Cálculo em Megabytes (MB) usando o bc
    RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc)
    SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc)
    TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc)

    # Imprime os dados formatados
    printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
done
echo "---------------------------------------------------------------"
}
###############Fim da função consumo de usuários#################
##############Função gerencia usuários VPN#######################
function user_gerencia {
clear
STATUS_FILE="/var/log/openvpn/openvpn-status.log"
while true; do
USER=$(echo "$line" | cut -d',' -f2)
echo "======================================"
echo "   Gerenciar usuários VPN:            "
printf "%-15s %-12s %-12s %-12s\n" "$USER" 
echo "======================================"
echo ""
echo "[1] Adicionar usuário"
echo "[2] Deslogar usuário"	
echo "[3] Remover usuário"
echo "[4] Sair"					
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
            #sleep 1
            ;;
        [3])
            #sleep 1
            #break # Sai do loop while
            ;;
        [4])
            echo ""
            echo "Saindo..."
            sleep 1
            clear
            menu_ovp
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
#############Fim da função de gerenciar usuários##################
#############Ver consumo da VPN###################################
function relatorio_consumo {
clear
while true; do
INTERFACE="tun0"
CURRENRT=$(whoami)
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
############Função que mede a velocidade tun0###############
function velocidade_tun0 {
#!/bin/bash
clear
# 1. Identifica o IP interno da interface tun0
IP_TUN0=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
# 2. Verifica se a VPN está ativa
if [ -z "$IP_TUN0" ]; then
    echo "❌ Erro: Interface tun0 não encontrada ou VPN está offline."
    exit 1
fi

echo "================================================================="
echo "           TESTE DE VELOCIDADE - INTERFACE TUN0"
echo "           IP Interno: $IP_TUN0"
echo "================================================================="

# 3. Executa o teste usando o IP da tun0 como origem
# O parâmetro --source força o tráfego a sair por esse IP
echo "Iniciando teste (isso pode levar alguns segundos)..."
speedtest-cli --source "$IP_TUN0" --simple
echo "================================================================="
}
##########Fim Função que mede a velocidade tun0######
function tun0_monitor {
clear
# Detecta a interface de rede ativa que tem a rota padrão
INTERFACE='tun0'
echo "Monitorando a interface: $INTERFACE"
vnstat -l -i "$INTERFACE"
}
function menu_ovp {
clear
while true; do
CURRENRT=$(whoami)
echo "================================================================="
echo "                         Menu Open VPN:                          "
echo "================================================================="
echo ""
echo "[1] Testar velocidade			[5] Monitorar a tun0"
echo "[2] Usuários online 			[6] Gerenciar usuário"
echo "[3] Ver relatório de consumo		[7] Sair"
echo "[4] Ver consumo por usuário"					
echo ""
read -n 1 -p "Digite a opção desejada: " OPCAO
echo ""
case $OPCAO in
        [1])
            velocidade_tun0
            #sleep 1
            ;;
        [2])
	if [ "$EUID" -ne 0 ]; then
	  echo -e "\033[31mPor favor execute esse script como sudo!"
	  echo -e "\033[0m"
	  exit 1
	fi
            user_online
            #sleep 1
            ;;
        [3])
            relatorio_consumo
            #sleep 1
            #break # Sai do loop while
            ;;
        [4])
            user_cosumo
            #sleep 1
            ;;
        [5])
            tun0_monitor
            #sleep 1
            ;;
        [6])
           user_gerencia
            #sleep 1
            ;;
        [7])
            echo ""
            echo "Saindo..."
            sleep 1
            clear
            exit 1
            ;;
        [8])
	    #user_gerencia
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
menu_ovp
