#!/bin/bash

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# Verifica root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# --- CONFIGURAÇÃO DE CAMINHOS ---
# O Angristan usa geralmente estes caminhos:
INSTALLER_PATH="/home/jutair/configdebian-main/openvpn-install.sh"
[ ! -f "$INSTALLER_PATH" ] && INSTALLER_PATH="./openvpn-install.sh"

# Caminho do LOG (Tenta os dois mais comuns)
STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

# --- FUNÇÕES ---
veri_openvpn () {
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não instalado.${SEM_COR}"
        mkdir -p "/home/jutair/configdebian-main"
        wget -P "/home/jutair/configdebian-main" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
        chmod +x "$INSTALLER_PATH"
        sudo "$INSTALLER_PATH" install
    fi

    # Auto-detecção do Easy-RSA
    [ -d "/etc/openvpn/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/easy-rsa"
    [ -d "/etc/openvpn/server/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    
    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    
    # Garante o index.txt para evitar erros no menu
    if [ ! -f "$INDEX_FILE" ]; then
        mkdir -p "$(dirname "$INDEX_FILE")"
        touch "$INDEX_FILE"
        chmod 644 "$INDEX_FILE"
    fi
    echo -e "${VERDE}[OK] Sistema validado.${SEM_COR}\n"
    sleep 1
    mover_ovp
}
#################Função para ver usuários online#################
user_online() {
    clear
    # Define o caminho do log (prioriza o padrão do Angristan)
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

    echo "==============================================================="
    echo "                USUÁRIOS CONECTADOS AGORA"
    echo "==============================================================="
    printf "%-15s %-20s %-15s %-10s\n" "USUÁRIO" "IP REAL" "IP VPN" "DESDE"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "\033[31mErro: Arquivo de log não encontrado em $STATUS_FILE\033[0m"
        echo "Dica: Verifique se o OpenVPN está rodando."
    else
        # Processa o log - Formato CLIENT_LIST (vírgulas)
        # O grep busca apenas linhas de clientes ativos e ignora o cabeçalho
        LISTA=$(grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name")

        if [ -z "$LISTA" ]; then
            echo "Nenhum usuário conectado no momento."
        else
            echo "$LISTA" | while read -r line; do
                USER=$(echo "$line" | cut -d',' -f2)
                IP_REAL=$(echo "$line" | cut -d',' -f3 | cut -d':' -f1)
                IP_VPN=$(echo "$line" | cut -d',' -f4)
                # Formata data e hora
                DESDE=$(echo "$line" | cut -d',' -f8 | awk '{print $2" "$3}')

                printf "%-15s %-20s %-15s %-10s\n" "$USER" "$IP_REAL" "$IP_VPN" "$DESDE"
            done
        fi

        echo "---------------------------------------------------------------"
        TOTAL=$(echo "$LISTA" | grep -v "^$" | wc -l)
        echo "Total de conexões: $TOTAL"
    fi

    echo "---------------------------------------------------------------"
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
#################Fim da função usuários online###################
user_consumo() {
    clear
    # Detecta o log corretamente
    STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
    [ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

    echo "==============================================================="
    echo "             CONSUMO DE DADOS (Sessão Atual)"
    echo "==============================================================="
    printf "%-15s %-12s %-12s %-12s\n" "USUÁRIO" "RECEBIDO" "ENVIADO" "TOTAL"
    echo "---------------------------------------------------------------"

    if [ ! -f "$STATUS_FILE" ]; then
        echo "Erro: Arquivo de log não encontrado."
        read dummy
        return
    fi

    # Filtra apenas as linhas de clientes e processa
    grep "^CLIENT_LIST" "$STATUS_FILE" | grep -v "Common Name" | while read -r line; do
        
        USER=$(echo "$line" | cut -d',' -f2)
        
        # Captura os bytes e garante que se estiver vazio, vire 0 para não travar o 'bc'
        RECV_B=$(echo "$line" | cut -d',' -f5 | tr -d '\r' | awk '{print ($1 == "" ? 0 : $1)}')
        SENT_B=$(echo "$line" | cut -d',' -f6 | tr -d '\r' | awk '{print ($1 == "" ? 0 : $1)}')

        # Realiza os cálculos apenas se RECV_B e SENT_B forem números
        RECV_MB=$(echo "scale=2; $RECV_B/1024/1024" | bc 2>/dev/null || echo "0.00")
        SENT_MB=$(echo "scale=2; $SENT_B/1024/1024" | bc 2>/dev/null || echo "0.00")
        TOTAL_MB=$(echo "scale=2; ($RECV_B+$SENT_B)/1024/1024" | bc 2>/dev/null || echo "0.00")

        printf "%-15s %-12s %-12s %-12s\n" "$USER" "${RECV_MB}MB" "${SENT_MB}MB" "${TOTAL_MB}MB"
    done

    echo "---------------------------------------------------------------"
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
#############################Fim da função ver consumo de usuários##########################
testa_velocidade() {
    clear
    echo "==============================================================="
    echo "           TESTE DE VELOCIDADE - INTERFACE TUN0"
    echo "==============================================================="
    
    # 1. Identifica o IP interno da interface tun0
    IP_TUN0=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    # 2. Verifica se a interface tun0 existe/está ativa
    if [ -z "$IP_TUN0" ]; then
        echo -e "\033[31mErro: Interface tun0 não encontrada ou VPN está offline.\033[0m"
        echo "Pressione ENTER para voltar..."
        read dummy
        return
    fi

    echo "IP da Interface: $IP_TUN0"
    echo "Aguarde, testando a conexão via túnel VPN..."
    echo "Isto pode levar até 1 minuto..."

    # 3. Executa o teste usando o parâmetro --source para forçar a tun0
    # Armazenamos em uma variável para processar os dados de uma vez só
    RESULTADO=$(speedtest-cli --source "$IP_TUN0" --simple 2>/dev/null)

    if [ -z "$RESULTADO" ]; then
        echo -e "\033[31mErro ao realizar o teste. Verifique se o speedtest-cli está instalado.\033[0m"
    else
        PING=$(echo "$RESULTADO" | grep "Ping" | awk '{print $2}')
        DOWNLOAD=$(echo "$RESULTADO" | grep "Download" | awk '{print $2}')
        UPLOAD=$(echo "$RESULTADO" | grep "Upload" | awk '{print $2}')

        clear
        echo "==============================================================="
        echo "           RESULTADO DA VELOCIDADE (TUN0)"
        echo "==============================================================="
        echo "Download : $DOWNLOAD Mbps"
        echo "Upload   : $UPLOAD Mbps"
        echo "Ping     : $PING ms"
        echo "==============================================================="
    fi
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
########################Função monitora tun0#########################
monitora_tun() {
    clear
    echo "==============================================================="
    echo "          MONITORANDO TUN0 EM TEMPO REAL (Live)"
    echo "      Pressione CTRL+C para parar e voltar ao menu"
    echo "==============================================================="
    echo ""
    
    # Verifica se a interface tun0 existe antes de iniciar
    if ! ip link show tun0 > /dev/null 2>&1; then
        echo -e "\033[31mErro: Interface tun0 não está ativa no momento.\033[0m"
        echo "Pressione ENTER para voltar..."
        read dummy
        return
    fi

    # O comando vnstat -l (live) mostra o tráfego em tempo real
    # Ele continuará rodando até que o usuário pressione CTRL+C
    vnstat -l -i tun0

    echo ""
    echo "---------------------------------------------------------------"
    echo "Monitoramento encerrado."
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
###############Função lista ovpns################################################
listar_ovpns() {
    clear
    echo "======================================"
    echo "      ARQUIVOS DE CONFIGURAÇÃO        "
    echo "======================================"
    find /home -name "*.ovpn" 2>/dev/null
    find /root -name "*.ovpn" 2>/dev/null
    echo "--------------------------------------"
    echo "Pressione ENTER para voltar..."
    read dummy
}
####################Fim da função lista ovpns####################################
####################Função baixa ovpn############################################
baixa() {
    IP_WAN=$(curl -s ifconfig.me)
    USER_ATUAL=${SUDO_USER:-$(whoami)}
    clear
    INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

    echo "==============================================================="
    echo "              RELATÓRIO DE USUÁRIOS E DOWNLOAD"
    echo "==============================================================="

    if [ ! -f "$INDEX_FILE" ]; then
        echo "Erro: Banco de dados de usuários não encontrado."
        read dummy; return
    fi

    # --- Listagem de Ativos ---
    echo -e "\033[32m[ ATIVOS / VÁLIDOS ]\033[0m"
    printf "%-20s %-25s\n" "NOME" "DATA CRIACAO"
    echo "---------------------------------------------------------------"
    grep "^V" "$INDEX_FILE" | while read -r line; do
        USER=$(echo "$line" | awk -F'=' '{print $2}')
        DATA_RAW=$(echo "$line" | awk '{print $2}')
        # Formatação universal (Funciona em Bash e Dash)
        DATA_BR="20$(echo "$DATA_RAW" | cut -c 1-2)-$(echo "$DATA_RAW" | cut -c 3-4)-$(echo "$DATA_RAW" | cut -c 5-6)"
        printf "%-20s %-10s\n" "$USER" "$DATA_BR"
    done

    echo ""
    read -p "Digite o nome do usuário para localizar o .ovpn: " NOME
    [ -z "$NOME" ] && return

    echo -e "\nBuscando arquivo... Aguarde."

    # BUSCA AUTOMÁTICA: Procura em /home e /root pelo arquivo .ovpn exato
    ARQUIVO_ORIGEM=$(find /home /root -name "${NOME}.ovpn" 2>/dev/null | head -n 1)

    if [ -n "$ARQUIVO_ORIGEM" ] && [ -f "$ARQUIVO_ORIGEM" ]; then
        echo -e "---------------------------------------------------------------"
        echo -e "\033[32m✅ ARQUIVO LOCALIZADO!\033[0m"
        echo -e "Caminho no Servidor: $ARQUIVO_ORIGEM"
        echo -e "---------------------------------------------------------------"
        echo -e "Para baixar no seu Windows, abra o CMD ou PowerShell e cole:"
        echo ""
        echo -e "\033[33mscp ${USER_ATUAL}@${IP_WAN}:${ARQUIVO_ORIGEM} ./\033[0m"
        echo -e "---------------------------------------------------------------"
        echo -e "O arquivo será salvo na pasta onde seu terminal estiver aberto."
    else
        echo -e "---------------------------------------------------------------"
        echo -e "\033[31m❌ ERRO: O arquivo ${NOME}.ovpn não foi encontrado no servidor.\033[0m"
        echo -e "Certifique-se de que o usuário foi criado corretamente."
    fi

    echo ""
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
####################Fim da função baixa ovpn###################################
####################Função listar usuários######################################
listar_usuarios() {
    clear
    # Caminho do arquivo de índices do Easy-RSA
    INDEX_FILE="/etc/openvpn/server/easy-rsa/pki/index.txt"

    echo "==============================================================="
    echo "              RELATÓRIO DE USUÁRIOS DO SISTEMA"
    echo "==============================================================="

    if [ ! -f "$INDEX_FILE" ]; then
        echo -e "\033[31mErro: Banco de dados de usuários não encontrado.\033[0m"
        echo "Caminho esperado: $INDEX_FILE"
        read dummy; return
    fi

    # --- Seção de Ativos ---
    echo -e "\033[32m[ ATIVOS / VÁLIDOS ]\033[0m"
    printf "%-20s %-25s\n" "NOME DO USUÁRIO" "DATA DE CRIAÇÃO"
    echo "---------------------------------------------------------------"
    
    grep "^V" "$INDEX_FILE" | while read -r line; do
        # Extrai o nome do usuário (Common Name)
        USER=$(echo "$line" | awk -F'=' '{print $2}')
        # Extrai e formata a data de criação
        DATA_RAW=$(echo "$line" | awk '{print $2}')
        DATA_BR=$(echo "20${DATA_RAW:0:2}-${DATA_RAW:2:2}-${DATA_RAW:4:2}")
        
        printf "%-20s %-25s\n" "$USER" "$DATA_BR"
    done

    echo ""

    # --- Seção de Banidos ---
    echo -e "\033[31m[ BANIDOS / REVOGADOS ]\033[0m"
    printf "%-20s %-25s\n" "NOME DO USUÁRIO" "DATA DA REVOGAÇÃO"
    echo "---------------------------------------------------------------"
    
    grep "^R" "$INDEX_FILE" | while read -r line; do
        USER=$(echo "$line" | awk -F'=' '{print $2}')
        # No caso de revogados, a data de revogação é o terceiro campo
        DATA_RAW=$(echo "$line" | awk '{print $3}')
        DATA_BR=$(echo "20${DATA_RAW:0:2}-${DATA_RAW:2:2}-${DATA_RAW:4:2}")
        
        printf "%-20s %-25s\n" "$USER" "$DATA_BR"
    done

    echo "==============================================================="
    echo "Pressione ENTER para voltar ao menu..."
    read dummy
}
####################Fim da função listar usuários################################
###############Função para gerenciar usuários####################################
user_gerencia() {
# Caminho para o instalador do Angristan
INSTALLER="/home/jutair/configdebian-main/openvpn-install.sh"

# Cores para o terminal
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0m'

# Função para Adicionar Usuário
add_user() {
    clear
    echo "======================================"
    echo "      ADICIONAR NOVO USUÁRIO          "
    echo "======================================"
    read -p "Digite o nome do usuário: " CLIENT
    
    if [ -z "$CLIENT" ]; then
        echo -e "${VERMELHO}Nome não pode ser vazio!${SEM_COR}"
        sleep 2
        return
    fi

    # Nova sintaxe do Angristan: client add <nome>
    # Usamos --batch ou apenas os comandos diretos
    sudo "$INSTALLER" client add "$CLIENT"
    
    echo -e "\n${VERDE}Processo finalizado para: $CLIENT${SEM_COR}"
    echo "Pressione ENTER para voltar..."
    read dummy
}

# Função para Remover Usuário
remove_user() {
    clear
    echo "======================================"
    echo "      REMOVER USUÁRIO EXISTENTE       "
    echo "======================================"
    
    # Lista os usuários existentes (PKI do Easy-RSA)
    if [ -f /etc/openvpn/server/easy-rsa/pki/index.txt ]; then
        echo "Usuários encontrados:"
        grep "^V" /etc/openvpn/server/easy-rsa/pki/index.txt | awk -F'=' '{print $2}'
        echo "--------------------------------------"
    else
        echo "Nenhum usuário listado no sistema."
    fi

    read -p "Digite o nome exato do usuário para REMOVER: " CLIENT
    
    if [ -z "$CLIENT" ]; then
        return
    fi

    # Nova sintaxe do Angristan: client revoke <nome>
    sudo "$INSTALLER" client revoke "$CLIENT"
    
    echo -e "\n${VERMELHO}Processo de revogação finalizado: $CLIENT${SEM_COR}"
    echo "Pressione ENTER para voltar..."
    read dummy
}

# Menu de Gerenciamento
while true; do
    clear
    echo "======================================"
    echo "     GERENCIAMENTO DE USUÁRIOS        "
    echo "======================================"
    echo "[1] Adicionar Usuário"
    echo "[2] Remover Usuário"
    echo "[3] Listar Usuários do OpenVPN"
    echo "[4] Baixar arquivo via SSH"
    echo "[5] Voltar ao Menu Principal"
    echo "======================================"
    read -p "Opção: " OP
    
    case $OP in
        1) add_user ;;
        2) remove_user ;;
        3) listar_usuarios ;;
        4) baixa ;;
        5) exit 0 ;;
        *) echo "Opção inválida"; sleep 1 ;;
    esac
done
}
###########################Fim da função gerenciar usuários####################
###########################Função move ovp#####################################
mover_ovp() {
    ORIGEM="/root"
    NOME_USUARIO=${SUDO_USER:-$(whoami)}
    
    # CORREÇÃO: Caminho absoluto começando com / e dentro da home do usuário
    DESTINO="/home/$NOME_USUARIO/clientes_ovp"

    # 1. Cria a pasta de destino se ela não existir
    if [ ! -d "$DESTINO" ]; then
        echo "Criando diretório $DESTINO..."
        mkdir -p "$DESTINO"
        # CORREÇÃO: Usa a variável informada pelo usuário
        chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"
    fi

    # 2. Verifica se existem arquivos .ovpn na root
    ARQUIVOS_NA_ROOT=$(ls $ORIGEM/*.ovpn 2>/dev/null)

    if [ -z "$ARQUIVOS_NA_ROOT" ]; then
        echo -e "\033[33mNenhum novo arquivo .ovpn encontrado em $ORIGEM.\033[0m"
    else
        echo "Arquivos encontrados! Iniciando transferência..."
        
        for arq in $ARQUIVOS_NA_ROOT; do
            NOME_ARQ=$(basename "$arq")
            
            # Move o arquivo para o destino
            mv "$arq" "$DESTINO/"
            
            # CORREÇÃO: Ajusta permissões usando a variável correta
            chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO/$NOME_ARQ"
            chmod 644 "$DESTINO/$NOME_ARQ"
            
            echo -e "\033[32m[OK]\033[0m $NOME_ARQ -> $DESTINO"
        done
        echo -e "\n\033[32mTransferência concluída com sucesso!\033[0m"
    fi

    echo "==============================================================="
    echo "Arquivos dos clientes OpenVPN estão em: $DESTINO"
    echo "Aguarde 1 segundo..."
    sleep 1
    menu_ovp
}
##############################Fim da função move ovp#########################
##################################################################################
menu_ovp() {
    while true; do
        clear
        echo "================================================================="
        echo "                         Menu Open VPN:                          "
        echo "================================================================="
        echo "[1] Testar velocidade      [5] Monitorar tun0 (vnstat)"
        echo "[2] Usuários Online        [6] Gerenciar Usuários"
        echo "[3] Relatório da VPN       [7] Sair"
        echo "[4] Consumo dos Usuários"
        echo "================================================================="
        read -n 1 -p "Digite a opção: " OPCAO
        echo ""
        case $OPCAO in
            1) testa_velocidade ;;
            2) user_online ;;
            3) vnstat -d -i tun0; read -n 1 ;;
            4) user_consumo ;;
            5) vnstat -l -i tun0 ;;
            6) user_gerencia ;;
            7) exit 0 ;;
        esac
    done
}

# --- INÍCIO ---
clear
veri_openvpn
