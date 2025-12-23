#!/bin/bash
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
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
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
[ ! -f "$INSTALLER_PATH" ] && INSTALLER_PATH="./openvpn-install.sh"

# Caminho do LOG (Tenta os dois mais comuns)
STATUS_FILE="/etc/openvpn/server/openvpn-status.log"
[ ! -f "$STATUS_FILE" ] && STATUS_FILE="/var/log/openvpn/openvpn-status.log"

ARQUIVO="/etc/openvpn/clientes_ovp/ips_conectados.txt"

# $script_type é uma variável do OpenVPN (client-connect ou client-disconnect)
case "$script_type" in
    client-connect)
        # Adiciona o IP na lista se não existir
        if ! grep -q "$trusted_ip" "$ARQUIVO"; then
            echo "$trusted_ip" >> "$ARQUIVO"
            # Aplica regra no Firewall imediatamente
            sudo ufw allow from "$trusted_ip" to any
        fi
        ;;
    client-disconnect)
        # Remove o IP da lista
        sed -i "/$trusted_ip/d" "$ARQUIVO"
        # Remove a regra do Firewall
        sudo ufw delete allow from "$trusted_ip" to any
        ;;
esac

# --- FUNÇÕES ---
veri_openvpn () {
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
    if ! command -v openvpn >/dev/null 2>&1; then
        echo -e "${AMARELO}[AVISO] OpenVPN não instalado.${SEM_COR}"
        sudo mkdir -p "/home/$USER_ATUAL/configdebian-main"
        sudo wget -P "/home/$USER_ATUAL/configdebian-main" https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
        sudo chmod +x "$INSTALLER_PATH"
        sudo "$INSTALLER_PATH" install
    fi

    # Auto-detecção do Easy-RSA
    [ -d "/etc/openvpn/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/easy-rsa"
    [ -d "/etc/openvpn/server/easy-rsa" ] && EASYRSA_DIR="/etc/openvpn/server/easy-rsa"
    
    INDEX_FILE="$EASYRSA_DIR/pki/index.txt"
    
    # Garante o index.txt para evitar erros no menu
    if [ ! -f "$INDEX_FILE" ]; then
        sudo mkdir -p "$(dirname "$INDEX_FILE")"
        sudo touch "$INDEX_FILE"
        sudo chmod 644 "$INDEX_FILE"
    fi
    echo -e "${VERDE}[OK] Sistema validado.${SEM_COR}\n"
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
    echo "      Pressione CTRL+C para parar e ver o resumo"
    echo "==============================================================="
    
    if ! ip link show tun0 > /dev/null 2>&1; then
        echo -e "${VERMELHO}Erro: Interface tun0 não está ativa.${SEM_COR}"
        read -p "Pressione ENTER..." dummy
        return
    fi

    # Bloqueia o CTRL+C para o script pai (menu)
    trap '' INT 

    # Roda o vnstat em um subshell que aceita o CTRL+C
    ( trap - INT; vnstat -l -i tun0 )

    echo -e "\n---------------------------------------------------------------"
    echo "Monitoramento encerrado."
    
    # Restaura o CTRL+C
    trap - INT 

    # OBRIGA o usuário a apertar ENTER antes de voltar ao menu
    echo -n "Pressione [ENTER] para voltar ao menu..."
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
    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
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
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
# Caminho para o instalador do Angristan
INSTALLER="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"

# Cores para o terminal
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0m'

# Função para Adicionar Usuário
add_user() {
    USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
    clear
    echo "======================================"
    echo "      ADICIONAR NOVO USUÁRIO          "
    echo "======================================"
    
    INSTALLER="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
    
    # --- CORREÇÃO DE SEGURANÇA ---
    # Verifica se a chave tls-crypt existe, se não, tenta localizar
    if [ ! -f /etc/openvpn/server/tls-crypt.key ]; then
        if [ -f /etc/openvpn/tls-crypt.key ]; then
            sudo ln -s /etc/openvpn/tls-crypt.key /etc/openvpn/server/tls-crypt.key
        elif [ -f /etc/openvpn/server/ta.key ]; then
            echo -e "${AMARELO}[AVISO] Usando ta.key em vez de tls-crypt.key${SEM_COR}"
        fi
    fi

    read -p "Digite o nome do usuário: " CLIENT
    
    if [ -z "$CLIENT" ]; then
        echo -e "${VERMELHO}Nome não pode ser vazio!${SEM_COR}"
        sleep 2; return
    fi

    echo -e "${AMARELO}Gerando certificado para $CLIENT...${SEM_COR}"
    
    # Executa o instalador e captura erros
    if sudo bash "$INSTALLER" client add "$CLIENT"; then
        echo -e "\n${VERDE}✅ Sucesso: Certificado gerado para $CLIENT${SEM_COR}"
    else
        echo -e "\n${VERMELHO}❌ ERRO: Falha ao gerar o arquivo .ovpn${SEM_COR}"
        echo "Verifique o log: tail -n 20 openvpn-install.log"
    fi
    
    echo "Pressione ENTER para continuar..."
    read dummy
    atualiza_ovp
}
# Função para Remover Usuário
remove_user() {
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
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
    sudo rm /home/$USER_ATUAL/clientes_ovp/$CLIENT.ovpn
    echo -e "\n${VERMELHO}Processo de revogação finalizado: $CLIENT${SEM_COR}"
    echo "Pressione ENTER para voltar..."
    read dummy
    atualiza_ovp
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
    clear
    # Identifica o usuário real (mesmo usando sudo)
    NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
    DESTINO="/home/$NOME_USUARIO/clientes_ovp"
    # 1. Cria o destino e ajusta permissões da pasta
    if [ ! -d "$DESTINO" ]; then
        echo "Criando pasta de destino em $DESTINO..."
        mkdir -p "$DESTINO"
        chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"
    fi

    # 2. Busca arquivos .ovpn em /root e /home (excluindo a própria pasta destino)
    # O 'find' ignora a pasta de destino para não entrar em loop ou erro de permissão
    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)

    if [ -z "$ARQUIVOS" ]; then
        echo -e "\033[33mNenhum arquivo .ovpn novo foi localizado fora do destino.\033[0m"
    else
        echo "Arquivos localizados. Movendo para $DESTINO..."
        
        # O IFS= read ajuda a lidar com nomes de arquivos que tenham espaços
        echo "$ARQUIVOS" | while read -r arq; do
            NOME_ARQ=$(basename "$arq")
            
            # Move o arquivo
            mv "$arq" "$DESTINO/"
            
            # Ajusta o dono para o usuário não-root conseguir baixar via SCP
            chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO/$NOME_ARQ"
            chmod 644 "$DESTINO/$NOME_ARQ"
            
            echo -e "\033[32m[MOVIDO]\033[0m $NOME_ARQ"
        done
        echo -e "\n\033[32mTransferência concluída com sucesso!\033[0m"
    fi

    echo "==============================================================="
    echo "Localização atual: $DESTINO"
    sleep 1
    menu_ovp
}
##############################Fim da função move ovp#########################
##############################Atualiza ovp#######################################
###########################Função move ovp#####################################
atualiza_ovp() {
    clear
    # Identifica o usuário real (mesmo usando sudo)
    NOME_USUARIO=$(logname 2>/dev/null || echo $SUDO_USER)
    DESTINO="/home/$NOME_USUARIO/clientes_ovp"
    # 1. Cria o destino e ajusta permissões da pasta
    if [ ! -d "$DESTINO" ]; then
        echo "Criando pasta de destino em $DESTINO..."
        mkdir -p "$DESTINO"
        chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO"
    fi

    # 2. Busca arquivos .ovpn em /root e /home (excluindo a própria pasta destino)
    # O 'find' ignora a pasta de destino para não entrar em loop ou erro de permissão
    ARQUIVOS=$(find /root /home -name "*.ovpn" ! -path "$DESTINO/*" 2>/dev/null)

    if [ -z "$ARQUIVOS" ]; then
        echo -e "\033[33mNenhum arquivo .ovpn novo foi localizado fora do destino.\033[0m"
    else
        echo "Arquivos localizados. Movendo para $DESTINO..."
        
        # O IFS= read ajuda a lidar com nomes de arquivos que tenham espaços
        echo "$ARQUIVOS" | while read -r arq; do
            NOME_ARQ=$(basename "$arq")
            
            # Move o arquivo
            mv "$arq" "$DESTINO/"
            
            # Ajusta o dono para o usuário não-root conseguir baixar via SCP
            chown "$NOME_USUARIO:$NOME_USUARIO" "$DESTINO/$NOME_ARQ"
            chmod 644 "$DESTINO/$NOME_ARQ"
            
            echo -e "\033[32m[MOVIDO]\033[0m $NOME_ARQ"
        done
        echo -e "\n\033[32mTransferência concluída com sucesso!\033[0m"
    fi

    echo "==============================================================="
    echo "Localização atual: $DESTINO"
    user_gerencia
}
###########################Fim da função atualiza ovp##############################
##################################################################################
menu_ovp() {
        USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
        IP_INT=$(hostname -I | awk '{print $1}')
        IP_EXT=$(curl -4 -s ifconfig.me)
    while true; do
        clear
        echo "================================================================="
        echo "                         Menu Open VPN:                          "
        echo "IP Interno: $IP_INT | IP Externo: $IP_EXT"
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
            6) atualiza_ovp ;;
            7) 
            echo "Retornando ao menu principal..."
            # Garante que estamos na pasta certa e substitui o processo atual pelo menu principal
            cd "/home/$USER_ATUAL/configdebian-main/"
            exec sudo -E bash ./menu.sh
            ;;
        esac
    done
}

# --- INÍCIO ---
clear
veri_openvpn
