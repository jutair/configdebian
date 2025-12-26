#!/bin/bash
# gerencia_rede.sh - Segurança e Rede VPS (Versão Blindada 26/12/2025)
# --- CORES ---
VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; NC='\033[0m'

# --- 🛡️ VERIFICAÇÃO E AUTO-ELEVAÇÃO PARA SUDO ---
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    else
        echo -e "${AMARELO}🔐 Este script precisa de privilégios de ROOT.${NC}"
        exec sudo -E "$0" "$@"
    fi
    exit
fi

# --- RESTO DO CÓDIGO ---
echo "Agora eu tenho certeza que sou ROOT!"

# --- CONFIGURAÇÕES DE DIRETÓRIOS E IDENTIDADE ---
DIR_PROT="/etc/vps_protecao"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'
SSH_CONF="/etc/ssh/sshd_config"

# --- 🛡️ 1. VERIFICAÇÃO DE ROOT AMIGÁVEL AO SUDO ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${VERMELHO}❌ Erro: Este script exige privilégios administrativos.${NC}"
   echo -e "${AMARELO}O menu deve chamá-lo com 'sudo -E'.${NC}"
   sleep 2
   exit 1
fi

# 2. Carrega o Administrador Oficial dinamicamente
if [ -f "$DIR_PROT/config.conf" ]; then
    source "$DIR_PROT/config.conf"
else
    ADM_USER="root"
fi

# 3. Detecta o usuário real da sessão (Auditando quem está no teclado)
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_REAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_REAL=$(whoami)
fi

# --- 🛡️ SEGURANÇA MÁXIMA (ANTI-SHELL) ---
fechar_sessao_critica() {
    if [[ "$USER_REAL" != "$ADM_USER" && "$USER_REAL" != "root" ]]; then
        echo -e "\n${VERMELHO}⚠️ INTERRUPÇÃO DETECTADA! Encerrando sessão...${NC}"
        pkill -u "$USER_REAL" -9
        exit 1
    fi
}
# Captura Ctrl+C, Ctrl+Z e outras interrupções
trap fechar_sessao_critica SIGINT SIGTSTP SIGQUIT

# --- FUNÇÕES DE RESTRIÇÃO ---

verificar_permissao_adm() {
    if [[ "$USER_REAL" != "$ADM_USER" && "$USER_REAL" != "root" ]]; then
        clear
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "          ⚠️ ACESSO NEGADO: APENAS ADMINISTRADOR ⚠️"
        echo -e "${VERMELHO}===============================================================${NC}"
        echo -e "O usuário '${AMARELO}$USER_REAL${NC}' não tem permissão para esta função."
        
        # Alerta no Telegram se configurado
        if [ -f "$DIR_PROT/telegram.conf" ]; then
            source "$DIR_PROT/telegram.conf"
            MENSAGEM="🚫 <b>TENTATIVA DE ACESSO RESTRITO:</b>%0AAutor: <code>$USER_REAL</code>%0AFunção: Configurações Críticas de Rede/SSH"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID_CHAT" -d text="$MENSAGEM" -d parse_mode="HTML" > /dev/null
        fi
        sleep 3
        return 1
    fi
    return 0
}

# --- FUNÇÕES DO SISTEMA ---

ssh_config() {
    verificar_permissao_adm || return

    while true; do
        clear
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "                ${VERDE}CONFIGURAÇÃO DE ACESSO SSH${NC}"
        echo -e "${AZUL}===============================================================${NC}"
        echo -e "  [1] 🚪 Mudar Porta SSH"
        echo -e "  [2] 👤 Permitir/Bloquear Login Root"
        echo -e "  [3] 🔑 Permitir/Bloquear Senhas"
        echo -e "  [4] 👢 Desconectar Usuário Ativo"
        echo -e "  [5] ⬅️  Voltar"
        echo -e "${AZUL}---------------------------------------------------------------${NC}"
        read -n 1 -p " Digite a opção: " OP; echo ""
        case $OP in
            1) read -p " Nova Porta: " NP; ufw allow "$NP"/tcp; sed -i "/^Port /d" $SSH_CONF; echo "Port $NP" >> $SSH_CONF; systemctl restart ssh ;;
            2) echo -e "[1] Permitir [2] Bloquear"; read -n 1 R; [ "$R" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PermitRootLogin/d" $SSH_CONF; echo "PermitRootLogin $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            3) echo -e "[1] Ativar [2] Desativar"; read -n 1 S; [ "$S" == "1" ] && VAL="yes" || VAL="no"; sed -i "/^PasswordAuthentication/d" $SSH_CONF; echo "PasswordAuthentication $VAL" >> $SSH_CONF; systemctl restart ssh ;;
            4) 
                who
                read -p " Usuário para expulsar: " U
                if [[ "$U" == "$ADM_USER" || "$U" == "root" ]]; then
                    echo "Operação não permitida!"; sleep 2
                else
                    pkill -u "$U" -9; echo "Usuário $U expulso!"; sleep 2
                fi ;;
            5) break ;;
        esac
    done
}

configurar_telegram() {
    verificar_permissao_adm || return
    clear
    echo -e "${AMARELO}--- CONFIGURAR ALERTA TELEGRAM ---${NC}"
    read -p " Digite o Token do seu Bot: " NOVO_TOKEN
    read -p " Digite o seu ID do Telegram: " NOVO_ID
    
    mkdir -p "$DIR_PROT"
    echo "TOKEN=\"$NOVO_TOKEN\"" > "$DIR_PROT/telegram.conf"
    echo "ID_CHAT=\"$NOVO_ID\"" >> "$DIR_PROT/telegram.conf"
    chmod 600 "$DIR_PROT/telegram.conf"

    echo -e "${VERDE}✅ Configuração salva! Testando envio...${NC}"
    curl -s -X POST "https://api.telegram.org/bot$NOVO_TOKEN/sendMessage" -d chat_id="$NOVO_ID" -d text="✅ Alertas configurados para o Administrador: $ADM_USER" > /dev/null
    sleep 2
}

# --- MENU PRINCIPAL DO MÓDULO ---
while true; do
    IP_EXTERNO=$(curl -s --max-time 2 ifconfig.me || echo "OFFLINE")
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "             ${VERDE}GERENCIAMENTO DE REDE E SEGURANÇA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  IP Servidor: ${AMARELO}$IP_EXTERNO${NC}"
    echo -e "  Operador   : ${AMARELO}$USER_REAL${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 🛡️  Configurar SSH (Porta/Root/Senha)"
    echo -e "  [2] 📢 Configurar Telegram (Alertas)"
    echo -e "  [3] ⚡ Teste de Velocidade (Speedtest)"
    echo -e "  [4] 📊 Tráfego de Rede (vnStat)"
    echo -e "  [9] ⬅️  Voltar ao Menu Principal"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Escolha: " OP; echo ""

    case $OP in
        1) ssh_config ;;
        2) configurar_telegram ;;
        3) speedtest-cli --simple || echo "Instale: apt install speedtest-cli"; read -p "Enter..." ;;
        4) vnstat; read -p "Enter..." ;;
        9) exit 0 ;;
        *) sleep 1 ;;
    esac
done
