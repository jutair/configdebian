#!/bin/bash
# menu.sh - Painel de Gestão Diária

DIR_SCRIPTS="$HOME/configdebian-main"
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# Coleta o IP Externo (com timeout de 2 segundos para não travar o menu se cair a net)
IP_EXT=$(curl -s --max-time 2 ifconfig.me || echo "Erro ao obter IP")

# Conta usuários SSH (exclui o cabeçalho e conta linhas)
USER_SSH=$(who | wc -l)

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          PAINEL DE GESTÃO VPS - USUÁRIO: ${VERDE}$USER${NC}"
    echo -e "          IP EXTERNO: ${AMARELO}$IP_EXT${NC}"
    echo -e "          USUÁRIOS SSH: ${AMARELO}$USER_SSH${NC}"
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
        1) 
            if [ -f "$DIR_SCRIPTS/open_vpn_conf.sh" ]; then
                sudo -E bash "$DIR_SCRIPTS/open_vpn_conf.sh"
            else
                echo -e "${VERMELHO}Erro: Script da VPN não encontrado.${NC}"
                sleep 2
            fi
            ;;
        2) 
            if [ -f "$DIR_SCRIPTS/gerencia_rede.sh" ]; then
                sudo -E bash "$DIR_SCRIPTS/gerencia_rede.sh"
            else
                echo -e "${VERMELHO}Erro: Script de Rede não encontrado.${NC}"
                sleep 2
            fi
            ;;
        3) 
            if [ -f "$DIR_SCRIPTS/usuarios.sh" ]; then
                sudo -E bash "$DIR_SCRIPTS/usuarios.sh"
            else
                echo -e "${VERMELHO}Erro: Script de Usuários não encontrado.${NC}"
                sleep 2
            fi
            ;;
        4) 
            if [ -f "$DIR_SCRIPTS/update_sistema.sh" ]; then
                sudo -E bash "$DIR_SCRIPTS/update_sistema.sh"
            else
                echo -e "${VERMELHO}Erro: Script de Update não encontrado.${NC}"
                sleep 2
            fi
            ;;
        5) 
            clear
            echo -e "${VERDE}Saindo... Até logo!${NC}"
            exit 0 
            ;;
        *) 
            echo -e "${VERMELHO}Opção inválida!${NC}"
            sleep 1 
            ;;
    esac

    # Atualiza a contagem de usuários SSH ao retornar de qualquer sub-menu
    USER_SSH=$(who | wc -l)
done
