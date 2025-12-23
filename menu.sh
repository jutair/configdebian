#!/bin/bash

# --- CONFIGURAÇÃO INICIAL E CORES ---
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
SEM_COR='\033[0m'

# Detecta o usuário e o caminho home corretamente
USER_ATUAL=$(logname 2>/dev/null || echo $SUDO_USER)
HOME_HUMANA=$(getent passwd "$USER_ATUAL" | cut -d: -f6)
DIR_SCRIPTS="$HOME_HUMANA/configdebian-main"

# Verifica se o script está sendo executado como root/sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

# --- FUNÇÃO DE CABEÇALHO ---
cabecalho() {
    IP_INT=$(hostname -I | awk '{print $1}')
    IP_EXT=$(curl -4 -s ifconfig.me || echo "Offline")
    UPTIME=$(uptime -p)
    
    clear
    echo -e "${AZUL}===============================================================${SEM_COR}"
    echo -e "          PAINEL DE CONTROLE VPS - USUÁRIO: ${VERDE}$USER_ATUAL${SEM_COR}"
    echo -e "  IP INTERNO: $IP_INT | IP EXTERNO: $IP_EXT"
    echo -e "  STATUS: $UPTIME"
    echo -e "${AZUL}===============================================================${SEM_COR}"
}

# --- MENU PRINCIPAL ---
while true; do
    cabecalho
    echo -e "${AMARELO}Selecione uma categoria de gerenciamento:${SEM_COR}"
    echo ""
    echo -e "[1] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "[2] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "[3] 👤 Gerenciar Usuários do Sistema"
    echo -e "[4] 🆙 Atualizar Sistema e Pacotes"
    echo -e "[5] ⚙️  Configuração Inicial da Máquina"
    echo -e "[6] ❌ Sair"
    echo ""
    echo -e "${AZUL}---------------------------------------------------------------${SEM_COR}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1)
            if [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ]; then
                exec sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh"
            else
                echo -e "${VERMELHO}Erro: script open_vpn_conf.sh não encontrado!${SEM_COR}"; sleep 2
            fi
            ;;
        2)
            if [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ]; then
                exec sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh"
            else
                echo -e "${VERMELHO}Erro: script gerencia_rede.sh não encontrado!${SEM_COR}"; sleep 2
            fi
            ;;
        3)
            if [ -f "$DIR_SCRIPTS/usuarios.sh" ]; then
                exec sudo -E bash "$DIR_SCRIPTS/usuarios.sh"
            else
                echo -e "${VERMELHO}Erro: script usuarios.sh não encontrado!${SEM_COR}"; sleep 2
            fi
            ;;
        4)
            if [ -f "$DIR_SCRIPTS/update_sistema.sh" ]; then
                exec sudo -E bash "$DIR_SCRIPTS/update_sistema.sh"
            else
                echo -e "${VERMELHO}Erro: script update_sistema.sh não encontrado!${SEM_COR}"; sleep 2
            fi
            ;;
        5)
            if [ -f "$DIR_SCRIPTS/configura_sistema.sh" ]; then
                exec sudo -E bash "$DIR_SCRIPTS/configura_sistema.sh"
            else
                echo -e "${VERMELHO}Erro: script configura_sistema.sh não encontrado!${SEM_COR}"; sleep 2
            fi
            ;;
        6)
            echo -e "${VERDE}Saindo... Até logo!${SEM_COR}"
            exit 0
            ;;
        *)
            echo -e "${VERMELHO}Opção inválida!${SEM_COR}"
            sleep 1
            ;;
    esac
done
