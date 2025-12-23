#!/bin/bash
################################Função de redes########################
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
########################Função menu_segrede##############################
menu_segrede() {
################Função fire_config#######################################
fire_config() {
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}Execute como sudo!${SEM_COR}"
    exit 1
fi

############################ Funções de Instalação ############################

instalar_dependencias() {
    clear
    echo -e "${AMARELO}A verificar dependências...${SEM_COR}"
    
    if ! command -v ufw &> /dev/null; then
        echo "Instalando UFW..."
        apt update && apt install ufw -y
    fi

    if ! command -v fail2ban-client &> /dev/null; then
        echo "Instalando Fail2Ban..."
        apt update && apt install fail2ban -y
        systemctl enable fail2ban
        systemctl start fail2ban
    fi
    echo -e "${VERDE}Dependências verificadas!${SEM_COR}"
    sleep 1
}

############################ Funções do Firewall ############################
ver_status() {
    clear
    echo "======================================"
    echo "      STATUS DO FIREWALL (UFW)        "
    echo "======================================"
    sudo ufw status numbered
    echo "--------------------------------------"
    echo -e "${AMARELO}STATUS DO FAIL2BAN (Bans Ativos):${SEM_COR}"
    # Mostra quantos IPs foram banidos no SSH
    sudo fail2ban-client status sshd | grep "Currently banned"
    echo "--------------------------------------"
    read -p "Pressione ENTER..." d
}

gerenciar_fail2ban() {
    clear
    echo "======================================"
    echo "        GERENCIAR FAIL2BAN            "
    echo "======================================"
    echo "[1] Ver lista de IPs banidos (SSH)"
    echo "[2] Desbanir um IP"
    echo "[3] Ver logs de ataques em tempo real"
    echo "[4] Voltar"
    echo "======================================"
    read -n 1 -p "Opção: " F_OPCAO
    echo ""

    case $F_OPCAO in
        1)
            clear
            echo "IPs banidos no momento:"
            sudo fail2ban-client status sshd
            read -p "ENTER..." d
            ;;
        2)
            read -p "Digite o IP para desbanir: " IP_UNBAN
            sudo fail2ban-client set sshd unbanip "$IP_UNBAN"
            echo "Comando enviado para desbanir $IP_UNBAN"
            sleep 2
            ;;
        3)
            clear
            echo "Mostrando tentativas de login negadas (CTRL+C para sair):"
            sudo tail -f /var/log/auth.log | grep "Failed password"
            ;;
        4) return ;;
    esac
}

bloquear_ip() {
    clear
    read -p "Digite o IP para bloquear no Firewall: " IP_ALVO
    if [ -n "$IP_ALVO" ]; then
        sudo ufw deny from "$IP_ALVO"
        echo -e "${VERMELHO}IP $IP_ALVO bloqueado permanentemente.${SEM_COR}"
    fi
    sleep 2
}

############################ Menu ############################
menu_fw() {
    instalar_dependencias
    while true; do
        clear
        echo "================================================"
        echo "      FIREWALL E SEGURANÇA            "
        echo "================================================"
        echo "[1] Status Geral (Portas e Bans)"
        echo "[2] Abrir Porta (Allow)"
        echo "[3] Fechar Porta (Delete Rule)"
        echo "[4] Bloquear IP Manualmente"
        echo "[5] Menu Fail2Ban (Proteção Anti-Brute Force)"
        echo "[6] Resetar Firewall (Padrão Seguro)"
        echo "[7] Voltar ao Menu de Segurança da rede"
        echo "[8] Voltar ao Menu Principal"
        echo "================================================"
        read -n 1 -p "Opção: " OPCAO
        echo ""

        case $OPCAO in
            1) ver_status ;;
            2) 
                read -p "Porta/Serviço: " P; sudo ufw allow "$P"
                echo "Porta liberada!"; sleep 1 ;;
            3) 
                sudo ufw status numbered
                read -p "Número da regra para apagar: " N
                sudo ufw --force delete "$N"; sleep 1 ;;
            4) bloquear_ip ;;
            5) gerenciar_fail2ban ;;
            6) 
                sudo ufw --force reset
                sudo ufw allow ssh
                sudo ufw allow 1194/udp # OpenVPN
                sudo ufw --force enable
                echo "Reset concluído!"; sleep 2 ;;
             7) return ;;
             8) 
                cd "/home/$USER_ATUAL/configdebian-main/" 2>/dev/null || cd "/home/$USER_ATUAL/"
                exec sudo -E bash ./menu.sh 
                ;;
            *) echo "Inválido"; sleep 1 ;;
        esac
    done
}

menu_fw
}
################Fim da função fire_config################################
################Função ssh_config########################################
ssh_config() {
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}Execute como sudo!${SEM_COR}"
    exit 1
fi

SSH_CONF="/etc/ssh/sshd_config"

############################ Funções ############################

ver_status_ssh() {
    clear
    echo "======================================"
    echo "      STATUS DO SERVIÇO SSH          "
    echo "======================================"
    systemctl status ssh --no-pager | grep -E "Active|Main PID"
    echo "--------------------------------------"
    PORTA=$(grep "^Port" $SSH_CONF | awk '{print $2}')
    echo "PORTA ATUAL: ${PORTA:-22 (padrão)}"
    ROOT_L=$(grep "^PermitRootLogin" $SSH_CONF | awk '{print $2}')
    echo "LOGIN ROOT: ${ROOT_L:-prohibit-password}"
    PASS_A=$(grep "^PasswordAuthentication" $SSH_CONF | awk '{print $2}')
    echo "LOGIN POR SENHA: ${PASS_A:-yes (padrão)}"
    echo "--------------------------------------"
    echo "USUÁRIOS CONECTADOS AGORA:"
    who
    echo "--------------------------------------"
    read -p "Pressione ENTER..." d
}

alternar_senha_ssh() {
    clear
    echo -e "${VERMELHO}--- ATENÇÃO ---${SEM_COR}"
    echo "Se desativar a senha, precisará obrigatoriamente de uma Chave SSH"
    echo "configurada no 'authorized_keys' para não perder o acesso!"
    echo "--------------------------------------"
    echo "[1] Ativar Login por Senha (Padrão)"
    echo "[2] Desativar Login por Senha (Apenas Chaves - Seguro)"
    read -n 1 -p "Escolha: " OP_PASS
    echo ""

    case $OP_PASS in
        1)
            sudo sed -i '/^PasswordAuthentication/d' $SSH_CONF
            echo "PasswordAuthentication yes" | sudo tee -a $SSH_CONF > /dev/null
            echo -e "${VERDE}Login por senha ATIVADO.${SEM_COR}"
            ;;
        2)
            sudo sed -i '/^PasswordAuthentication/d' $SSH_CONF
            echo "PasswordAuthentication no" | sudo tee -a $SSH_CONF > /dev/null
            echo -e "${AMARELO}Login por senha DESATIVADO. Use chaves SSH!${SEM_COR}"
            ;;
    esac
    systemctl restart ssh
    sleep 2
}

mudar_porta_ssh() {
    clear
    read -p "Digite a nova porta SSH: " NOVA_PORTA
    if [[ "$NOVA_PORTA" =~ ^[0-9]+$ ]]; then
        sudo ufw allow "$NOVA_PORTA"/tcp
        sudo sed -i '/^Port /d' $SSH_CONF
        echo "Port $NOVA_PORTA" | sudo tee -a $SSH_CONF > /dev/null
        systemctl restart ssh
        echo -e "${VERDE}Porta alterada para $NOVA_PORTA e liberada no UFW!${SEM_COR}"
    else
        echo -e "${VERMELHO}Porta inválida.${SEM_COR}"
    fi
    sleep 2
}

alternar_root_login() {
    clear
    echo "[1] Permitir Root  [2] Bloquear Root"
    read -n 1 -p "Escolha: " OR
    case $OR in
        1) sudo sed -i '/^PermitRootLogin/d' $SSH_CONF; echo "PermitRootLogin yes" | sudo tee -a $SSH_CONF > /dev/null ;;
        2) sudo sed -i '/^PermitRootLogin/d' $SSH_CONF; echo "PermitRootLogin no" | sudo tee -a $SSH_CONF > /dev/null ;;
    esac
    systemctl restart ssh
    echo -e "\n${VERDE}Configuração aplicada!${SEM_COR}"
    sleep 2
}
#######################Funçaõ derrubar e revogar usuário######
derruba_user_ssh() {
    clear
    echo "======================================"
    echo "    DERRUBAR E REVOGAR ACESSO SSH     "
    echo "======================================"
    
    # 1. Listar usuários reais logados (evita mostrar processos do sistema)
    echo "Usuários conectados agora:"
    who | awk '{print $1, "(" $5 ")"}' | sort | uniq
    echo "--------------------------------------"
    
    read -p "Digite o NOME EXATO do usuário para expulsar: " USUARIO_ALVO

    if [ -z "$USUARIO_ALVO" ]; then
        echo -e "${VERMELHO}Nome inválido.${SEM_COR}"
        sleep 2
        return
    fi

    # Confirmar se o usuário existe no sistema
    if ! id "$USUARIO_ALVO" >/dev/null 2>&1; then
        echo -e "${VERMELHO}Erro: O usuário '$USUARIO_ALVO' não existe.${SEM_COR}"
        sleep 2
        return
    fi

    # 2. Bloquear o acesso (Revogar)
    # Bloqueia a senha e impede novos logins via SSH
    sudo usermod -L "$USUARIO_ALVO"
    
    # 3. Derrubar a conexão atual (Kill)
    # O pkill -u mata todos os processos pertencentes àquele usuário
    sudo pkill -u "$USUARIO_ALVO" -9

    echo -e "${VERDE}Sucesso: Conexão de $USUARIO_ALVO encerrada e acesso bloqueado!${SEM_COR}"
    echo "Nota: O usuário não conseguirá logar até ser desbloqueado."
    sleep 3
}
######################Fim da função derruba ssh###############
############################ Menu ############################
menu_ssh() {
    while true; do
        clear
        echo "========================================="
        echo "          CONFIGURAR O SSH             "
        echo "========================================="
        echo "[1] Ver Status e Conexões"
        echo "[2] Mudar Porta SSH"
        echo "[3] Ativar/Desativar Login Root"
        echo "[4] Ativar/Desativar Login por Senha"
        echo "[5] Ver Logs de Acesso (Últimos 20)"
        echo "[6] Derrubar Conexão"
        echo "[7] Retornar ao Menu Segurança de Rede"
        echo "[8] Retornar ao Menu Principal"
        echo "========================================="
        read -n 1 -p "Opção: " OPCAO
        echo ""

        case $OPCAO in
            1) ver_status_ssh ;;
            2) mudar_porta_ssh ;;
            3) alternar_root_login ;;
            4) alternar_senha_ssh ;;
            5) clear; tail -n 20 /var/log/auth.log | grep sshd; read -p "ENTER..." d ;;
            6) derruba_user_ssh ;;
            7) return ;;
            8) 
                cd "/home/$USER_ATUAL/configdebian-main/" 2>/dev/null || cd "/home/$USER_ATUAL/"
                exec sudo -E bash ./menu.sh 
                ;;
            *) echo "Inválido"; sleep 1 ;;
        esac
    done
}

menu_ssh
}
################Fim da função ssh_config#################################
        while true; do
            INTERFACE=$(ip route | grep default | awk '{print $5}')
            CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)
            clear
            echo "======================================"
            echo "     Painel de segurança da rede:     "
            echo "======================================"
            echo "Seu usuário: $CURRENRT"
            echo ""
            echo "[1] Firewall"
            echo "[2] SSH"
            echo "[3] Retornar ao Menu Gerencia Rede"
            echo "[4] Voltar ao Menu Principal"
            echo ""
            read -n 1 -p "Digite a opção desejada: " OPCAO
            echo ""
            case $OPCAO in
                [1]) config_firewall;;
                [2]) ssh_config ;;
                [3]) return ;;
                [4])
                     echo "Retornando ao menu principal..."
                     # Garante que estamos na pasta certa e substitui o processo atual pelo menu principal
                     cd "/home/$CURRENRT/configdebian-main/"
                    exec sudo -E bash ./menu.sh
                    ;; # Usa return para sair da função e voltar ao menu;;
                *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
            esac
        done
    }
   ########################Função menu_segrede##############################
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
        echo "[4] Segurança"
        echo "[5] Voltar ao Menu Principal"
        echo ""
        read -n 1 -p "Digite a opção desejada: " OPCAO
        echo ""
        case $OPCAO in
            [1]) testa_velocidade ;;
            [2]) monitora_placa ;;
            [3]) relatorio_consumo ;;
            [4]) menu_segrede ;; #Invertido os menus
            [5]) 
                 echo "Retornando ao menu principal..."
                 # Garante que estamos na pasta certa e substitui o processo atual pelo menu principal
                 cd "/home/$CURRENRT/configdebian-main/"
                 exec sudo -E bash ./menu.sh
                 ;; # Usa return para sair da função e voltar ao menu
            *) echo -e "\033[31mOpção inválida!\033[0m"; sleep 1 ;;
        esac
    done
}
gerencia_rede
