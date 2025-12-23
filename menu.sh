#!/bin/bash

# --- CONFIGURAÇÃO INICIAL E CORES ---
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0m'

# Detecta o usuário jutair como base (já que ele é o dono do projeto)
DIR_SCRIPTS="/home/jutair/configdebian-main"

# Verifica root
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como sudo!${SEM_COR}"
  exit 1
fi

cabecalho() {
    IP_INT=$(hostname -I | awk '{print $1}')
    IP_EXT=$(curl -4 -s ifconfig.me || echo "Offline")
    UPTIME=$(uptime -p)
    clear
    echo -e "${AZUL}===============================================================${SEM_COR}"
    echo -e "          PAINEL DE GESTÃO VPS - USUÁRIO: ${VERDE}$USER${SEM_COR}"
    echo -e "  IP INTERNO: $IP_INT | IP EXTERNO: $IP_EXT"
    echo -e "  STATUS: $UPTIME"
    echo -e "${AZUL}===============================================================${SEM_COR}"
}

while true; do
    cabecalho
    echo -e "${AMARELO}Selecione uma opção de gerenciamento:${SEM_COR}"
    echo ""
    echo -e "[1] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "[2] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "[3] 👤 Gerenciar Usuários do Sistema"
    echo -e "[4] 🆙 Atualizar Sistema e Pacotes"
    echo -e "[5] ❌ Sair"
    echo ""
    echo -e "${AZUL}---------------------------------------------------------------${SEM_COR}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" || echo "Erro!"; sleep 2 ;;
        2) [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" || echo "Erro!"; sleep 2 ;;
        3) [ -f "$DIR_SCRIPTS/usuarios.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/usuarios.sh" || echo "Erro!"; sleep 2 ;;
        4) [ -f "$DIR_SCRIPTS/update_sistema.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/update_sistema.sh" || echo "Erro!"; sleep 2 ;;
        5) echo -e "${VERDE}Saindo...${SEM_COR}"; exit 0 ;;
        *) echo -e "${VERMELHO}Opção inválida!${SEM_COR}"; sleep 1 ;;
    esac
done
