#!/bin/bash
# menu.sh - Painel de Gestão Diária

DIR_SCRIPTS="$HOME/configdebian-main"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
NC='\033[0m'

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          PAINEL DE GESTÃO VPS - USUÁRIO: ${VERDE}$USER${NC}"
    echo -e "          STATUS: $(uptime -p)"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "[1] 🌐 Gerenciar VPN (OpenVPN)"
    echo -e "[2] 🚀 Gerenciar Rede e Segurança (FW/SSH)"
    echo -e "[3] 👤 Gerenciar Usuários do Sistema"
    echo -e "[4] 🆙 Atualizar Sistema"
    echo -e "[5] ❌ Sair"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OPCAO
    echo ""

    case $OPCAO in
        1) [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh" ;;
        2) [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh" ;;
        3) [ -f "$DIR_SCRIPTS/usuarios.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/usuarios.sh" ;;
        4) [ -f "$DIR_SCRIPTS/update_sistema.sh" ] && exec sudo -E bash "$DIR_SCRIPTS/update_sistema.sh" ;;
        5) exit 0 ;;
    esac
done
