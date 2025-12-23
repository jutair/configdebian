#!/bin/bash

################################ Função de redes ########################
update_sistema() {
    NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
    DESTINO="/home/$NOME_USUARIO/configdebian-main"

    # Verifica se o script foi executado como root
    if [ "$EUID" -ne 0 ]; then
      echo -e "\033[31mPor favor execute esse script como sudo!\033[0m"
      sleep 2
      return
    fi

    # Limpeza de scripts antigos na home para evitar conflitos
    ARQUIVOS=$(find "/home/${NOME_USUARIO}/update_sistema.sh" ! -path "$DESTINO/*" 2>/dev/null)

    if [ -n "$ARQUIVOS" ]; then
        echo "Removendo o script de atualização antigo da pasta home..."
        sudo rm "/home/${NOME_USUARIO}/update_sistema.sh"
    fi

    echo "=========================================================================="
    echo "Baixando um novo script de atualização..."
    echo "=========================================================================="
    sudo wget -P "/home/${NOME_USUARIO}" "https://raw.githubusercontent.com/jutair/configdebian/refs/heads/main/update_sistema.sh"
    sudo chmod +x "/home/${NOME_USUARIO}/update_sistema.sh"
    
    echo "Iniciando atualização..."
    sleep 1
    # Substitui o processo atual pelo script de update
    exec sudo "/home/${NOME_USUARIO}/update_sistema.sh"
}

################### Fim da função update sistema #################################

function gerencia_rede {
    # Funções internas (testa_velocidade, monitora_placa, relatorio_consumo) 
    # mantidas conforme seu código original...
    
    function testa_velocidade {
        clear
        echo "======================================"
        echo "        Velocidade da rede:            "
        echo "======================================"
        echo "Aguarde, testando a conexão da VPS..."
        PING=$(speedtest-cli --simple | grep "Ping" | cut -d' ' -f2)
        DOWNLOAD=$(speedtest-cli --simple | grep "Download" | cut -d' ' -f2)
        UPLOAD=$(speedtest-cli --simple | grep "Upload" | cut -d' ' -f2)
        clear
        echo "Download : $DOWNLOAD Mbps"
        echo "Upload   : $UPLOAD Mbps"
        echo "Ping     : $PING ms"
        read -p "Pressione ENTER para voltar..." dummy
    }

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

    function relatorio_consumo {
        while true; do
            INTERFACE=$(ip route | grep default | awk '{print $5}')
            clear
            echo "======================================"
            echo "   Relatório de consumo de rede:      "
            echo "======================================"
            echo "[1] Anual  [2] Mensal  [3] Diário  [4] Voltar"
            echo ""
            read -n 1 -p "Digite a opção: " OPCAO
            echo ""
            case $OPCAO in
                1) clear; vnstat -y -i "$INTERFACE"; read -p "ENTER..." d ;;
                2) clear; vnstat -m -i "$INTERFACE"; read -p "ENTER..." d ;;
                3) clear; vnstat -d -i "$INTERFACE"; read -p "ENTER..." d ;;
                4) break ;;
            esac
        done
    }

    while true; do
        IP_EXTERNO=$(curl -4 -s ifconfig.me || curl -4 -s ident.me)
        clear
        echo "======================================"
        echo "           Gerenciar rede:            "
        echo "IP externo: $IP_EXTERNO" 
        echo "======================================"
        echo "[1] Testar velocidade"
        echo "[2] Monitorar placa de rede"
        echo "[3] Ver relatório de consumo"
        echo "[4] Voltar ao Menu Principal"
        echo ""
        read -n 1 -p "Opção: " OPCAO
        echo ""
        case $OPCAO in
            1) testa_velocidade ;;
            2) monitora_placa ;;
            3) relatorio_consumo ;;
            4) return ;; 
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}

#########################################################
menu() {
    sudo ntpdate-debian 2>/dev/null
    IP_EXTERNO=$(curl -4 -s ifconfig.me || curl -4 -s ident.me)
    IP_INTERNO=$(hostname -I | awk '{print $1}')
    CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)

    while true; do
        clear
        HORA_ATUAL=$(date '+%H:%M:%S')
        DATA_ATUAL=$(date '+%d/%m/%Y')
        
        echo "================================================================="
        echo "                    MENU PRINCIPAL                               "
        echo "Usuário: $CURRENRT"
        echo "================================================================="
        echo "DATA: $DATA_ATUAL                           HORA: $HORA_ATUAL"
        echo "IP Interno: $IP_INTERNO | IP Externo: $IP_EXTERNO"
        echo "================================================================="
        echo "Versão do script: 22/12/2025-4:2044:57"
        echo "================================================================="
        echo ""
        echo "[1] Gerenciar Sistema        [6] Gerenciar usuários"
        echo "[2] Gerenciar Rede           [7] Atualizar o sistema"
        echo "[3] Ver logs do sistema      [8] Gerenciar OpenVpn"
        echo "[5] Fazer Backup             [9] Sair"
        echo ""
        
        echo -n "Digite a opção desejada: "
        read -t 58 OPCAO || true

        case "$OPCAO" in
            1) echo "Em desenvolvimento..." ; sleep 1 ;;
            2) gerencia_rede ;;
            # CORREÇÃO: Espaço entre sudo e ./ para evitar erro de diretório
            6) exec sudo ./usuarios.sh ;;
            7) update_sistema ;;
            8) exec sudo ./open_vpn_conf.sh ;;
            9) 
                clear
                echo -e "\033[1;33m[!] Encerrando painel e voltando ao terminal...\033[0m"
                sleep 1
                # Encerra o grupo de processos do menu sem derrubar o SSH
                kill -TERM -$(ps -o pgid= -p $$ | grep -o '[0-9]*')
                exit 0
                ;;
            "") continue ;;
            *) echo -e "\n\033[31mOpção inválida: '$OPCAO'\033[0m" ; sleep 1 ;;
        esac
    done
}

# Início do Script
menu
