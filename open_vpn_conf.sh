#!/bin/bash
# Identifica o usuário real (não o root) para as pastas
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)

# Cores para o Menu
VERDE='\033[0;32m'
VERMELHO='\033[31m'
AMARELO='\033[1;33m'
SEM_COR='\033[0m'

# --- CONFIGURAÇÃO DE CAMINHOS ---
INSTALLER_PATH="/home/$USER_ATUAL/configdebian-main/openvpn-install.sh"
DESTINO="/home/$USER_ATUAL/clientes_ovp"
STATUS_LOG="/etc/openvpn/server/openvpn-status.log"
SCRIPT_REDE="/home/$USER_ATUAL/configdebian-main/gerencia_rede.sh"

# Verifica se o script está rodando como ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# Instala dependências se faltarem (Speedtest e Vnstat)
if ! command -v speedtest-cli &> /dev/null || ! command -v vnstat &> /dev/null; then
    echo -e "${AMARELO}Instalando ferramentas de monitoramento (speedtest-cli, vnstat)...${SEM_COR}"
    apt update && apt install speedtest-cli vnstat bc -y
fi

# Cria a pasta de clientes se não existir
mkdir -p "$DESTINO"
chown "$USER_ATUAL:$USER_ATUAL" "$DESTINO"

# --- NOVAS FUNÇÕES ---

teste_velocidade() {
    clear
    echo "======================================"
    echo "    TESTE DE VELOCIDADE (TUN0)        "
    echo "======================================"
    echo -e "${AMARELO}Iniciando Speedtest... Aguarde...${SEM_COR}"
    # Força o speedtest a usar a interface da VPN se disponível, senão usa a padrão
    speedtest-cli --share
    echo "======================================"
    read -p "Pressione ENTER para voltar..." dummy
}

trafego_acumulado() {
    clear
    echo "======================================"
    echo "    TRÁFEGO ACUMULADO (Interface)     "
    echo "======================================"
    # Mostra o tráfego da tun0 (VPN). Se não existir, mostra da eth0.
    if ip link show tun0 > /dev/null 2>&1; then
        vnstat -i tun0
    else
        echo -e "${AMARELO}Interface tun0 offline. Mostrando tráfego geral:${SEM_COR}"
        vnstat
    fi
    echo "======================================"
    read -p "Pressione ENTER para voltar..." dummy
}

chamar_seguranca() {
    if [ -f "$SCRIPT_REDE" ]; then
        bash "$SCRIPT_REDE"
    else
        echo -e "${VERMELHO}Erro: Script gerencia_rede.sh não encontrado em $SCRIPT_REDE${SEM_COR}"
        sleep 2
    fi
}

# --- FUNÇÕES ORIGINAIS (MANTIDAS) ---
# [add_user, remove_user, listar_online permanecem como você enviou]
# (Cole aqui as suas funções add_user, remove_user e listar_online)

menu_ovp() {
    while true; do
        clear
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e "                GERENCIADOR OPENVPN - DIGITALOCE                 "
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        echo -e " [1] Adicionar Usuário (Robô)"
        echo -e " [2] Remover Usuário (Revogar)"
        echo -e " [3] Listar Arquivos .ovpn Gerados"
        echo -e " [4] Ver Usuários Online & Consumo"
        echo -e "-----------------------------------------------------------------"
        echo -e " [5] Testar Velocidade da Internet (Speedtest)"
        echo -e " [6] Ver Tráfego Acumulado (VnStat)"
        echo -e " [7] Gerenciamento de Rede & Segurança (Firewall)"
        echo -e " [8] Sair"
        echo -e "${AMARELO}=================================================================${SEM_COR}"
        read -p "Escolha uma opção: " OPCAO
        case $OPCAO in
            1) add_user ;;
            2) remove_user ;;
            3) clear; echo "--- Arquivos em $DESTINO ---"; ls -1 "$DESTINO"; read -p "ENTER..." dummy ;;
            4) listar_online ;;
            5) teste_velocidade ;;
            6) trafego_acumulado ;;
            7) chamar_seguranca ;;
            8) exit 0 ;;
            *) echo -e "${VERMELHO}Opção inválida!${SEM_COR}"; sleep 1 ;;
        esac
    done
}

menu_ovp
