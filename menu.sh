#!/bin/bash
# ===============================================================
# menu.sh - PAINEL MESTRE DE GESTÃO VPS (Versão Blindada 2025)
# ===============================================================

# --- CONFIGURAÇÕES DE AMBIENTE ---
DIR_PROT="/etc/vps_protecao"
DIR_CONFIG="/opt/configdebian"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# 1. IDENTIFICAÇÃO DO ADMINISTRADOR
# Carrega o nome do admin definido para permitir saída ao terminal
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

# 2. DETECÇÃO DE USUÁRIO REAL (AUID)
# O AUID identifica o login original, mesmo se o usuário deu 'sudo su'
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_LOGADO=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_LOGADO=$(whoami)
fi

# --- 🛡️ BLINDAGEM DE SEGURANÇA (ANTI-TERMINAL) ---
# Função para impedir que usuários comuns acessem o terminal Bash
fechar_sistema() {
    clear
    if [ "$USER_LOGADO" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ ACESSO NEGADO: Encerrando conexão por segurança...${NC}"
        # Mata todos os processos do usuário logado e desconecta o SSH
        pkill -u "$USER_LOGADO" -9
        exit 1
    else
        echo -e "\n${AMARELO}Saindo para o modo Terminal Admin (Root)...${NC}"
        exit 0
    fi
}

# Bloqueia Ctrl+C, Ctrl+Z e interrupções durante a navegação
trap fechar_sistema SIGINT SIGTSTP SIGQUIT

# --- LOOP DO MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "          ${VERDE}PAINEL DE CONTROLE VPS - MESTRE${NC}"
    echo -e "  Logado como: ${AMARELO}$USER_LOGADO${NC} | Privilégio: ${VERDE}Operador${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🔑 Gestão de Usuários (SSH/Samba)"
    echo -e "  [2] 🌐 Gerenciar OpenVPN (Status/Arquivos)"
    echo -e "  [3] ⚡ Rede, Performance e Speedtest"
    echo -e "  [4] ⚙️  Configurações do Sistema e Senhas"
    echo -e "  [5] 📦 Central de Backup e Restauração"
    echo -e "  [6] 🔄 Atualizar Painel via GitHub"
    echo -e "  [0] 🚪 Sair e Desconectar"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    
    echo -ne " ${AZUL}Escolha uma opção:${NC} "
    read -n 1 OPCAO
    echo ""

    case $OPCAO in
        1) 
            [ -f "$DIR_CONFIG/usuarios.sh" ] && bash "$DIR_CONFIG/usuarios.sh" || echo -e "${VERMELHO}Módulo usuários.sh não encontrado!${NC}"
            ;;
        2) 
            [ -f "$DIR_CONFIG/open_vpn_conf.sh" ] && bash "$DIR_CONFIG/open_vpn_conf.sh" || echo -e "${VERMELHO}Módulo open_vpn_conf.sh não encontrado!${NC}"
            ;;
        3) 
            [ -f "$DIR_CONFIG/gerencia_rede.sh" ] && bash "$DIR_CONFIG/gerencia_rede.sh" || echo -e "${VERMELHO}Módulo gerencia_rede.sh não encontrado!${NC}"
            ;;
        4) 
            [ -f "$DIR_CONFIG/configura_sistema.sh" ] && bash "$DIR_CONFIG/configura_sistema.sh" || echo -e "${VERMELHO}Módulo configura_sistema.sh não encontrado!${NC}"
            ;;
        5) 
            [ -f "$DIR_CONFIG/backup.sh" ] && bash "$DIR_CONFIG/backup.sh" || echo -e "${VERMELHO}Módulo backup.sh não encontrado!${NC}"
            ;;
        6) 
            [ -f "$DIR_CONFIG/update_sistema.sh" ] && bash "$DIR_CONFIG/update_sistema.sh" || echo -e "${VERMELHO}Módulo update_sistema.sh não encontrado!${NC}"
            ;;
        0) 
            fechar_sistema 
            ;;
        *) 
            echo -e "${VERMELHO}Opção Inválida!${NC}"
            sleep 1 
            ;;
    esac
done
