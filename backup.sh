#!/bin/bash
# backup_geral.sh - Central de Backup e Restauração Blindada

# --- CONFIGURAÇÕES DE IDENTIDADE E CORES ---
DIR_PROT="/etc/vps_protecao"
AZUL='\033[0;34m'; VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'

# 1. Carrega o Administrador Oficial
[ -f "$DIR_PROT/config.conf" ] && source "$DIR_PROT/config.conf" || ADM_USER="root"

# 2. Detecção AUID (Absolute User ID)
AUID=$(cat /proc/self/loginuid 2>/dev/null)
if [ -n "$AUID" ] && [ "$AUID" != "4294967295" ] && [ "$AUID" != "0" ]; then
    USER_REAL=$(getent passwd "$AUID" | cut -d: -f1)
else
    USER_REAL=$(whoami)
fi

DATA=$(date +%d-%m-%Y_%H-%M)
ARQUIVO_BACKUP="/tmp/backup_vps_${DATA}.tar.gz"

# --- 🛡️ SEGURANÇA MÁXIMA (ANTI-SHELL) ---
fechar_sessao_backup() {
    if [ "$USER_REAL" != "$ADM_USER" ]; then
        echo -e "\n${VERMELHO}⚠️ TENTATIVA DE INTERRUPÇÃO! Encerrando sessão...${NC}"
        pkill -u "$USER_REAL" -9
        exit 1
    fi
}
# Bloqueia Ctrl+C, Ctrl+Z e envia sinal de kill se houver tentativa de quebra
trap fechar_sessao_backup SIGINT SIGTSTP SIGQUIT

# --- FUNÇÕES DE APOIO ---

verificar_adm() {
    if [ "$USER_REAL" != "$ADM_USER" ]; then
        echo -e "${VERMELHO}ERRO: Apenas o administrador ($ADM_USER) pode realizar esta ação!${NC}"
        sleep 3
        return 1
    fi
    return 0
}

# --- FUNÇÕES DO SISTEMA ---

gerar_backup() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERANDO BACKUP COMPACTADO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    echo -e "${AMARELO}[1/2]${NC} Coletando arquivos críticos e configurações..."
    
    # Backup de SSH, Samba, OpenVPN e Proteções do Sistema
    tar -czf "$ARQUIVO_BACKUP" \
        /etc/ssh/sshd_config \
        /etc/samba/smb.conf \
        /etc/openvpn \
        /etc/vps_protecao \
        /opt/configdebian \
        2>/dev/null

    chmod 600 "$ARQUIVO_BACKUP"
    echo -e "${VERDE}[OK]${NC} Backup gerado: $ARQUIVO_BACKUP"
}

restaurar_backup() {
    # Trava de segurança para restauração
    verificar_adm || return

    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERMELHO}RESTAURAÇÃO DE SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e " [1] Restaurar de Arquivo Local"
    echo -e " [2] Buscar de Servidor Remoto"
    echo -e " [3] Voltar"
    read -n 1 -p " Escolha: " OP_RES; echo ""

    case $OP_RES in
        1)
            read -p " Caminho completo do arquivo (.tar.gz): " CAMINHO
            if [ -f "$CAMINHO" ]; then
                echo -e "${AMARELO}Restaurando...${NC}"
                tar -xzf "$CAMINHO" -C /
                echo -e "${VERDE}Sucesso! Reiniciando serviços...${NC}"
                systemctl restart ssh samba openvpn 2>/dev/null
            else
                echo -e "${VERMELHO}Arquivo não encontrado!${NC}"
            fi ;;
        2)
            read -p " IP do Servidor: " R_IP
            read -p " Usuário: " R_USER
            read -p " Caminho no Servidor: " R_PATH
            scp "${R_USER}@${R_IP}:${R_PATH}" /tmp/restaura.tar.gz
            if [ -f /tmp/restaura.tar.gz ]; then
                tar -xzf /tmp/restaura.tar.gz -C /
                echo -e "${VERDE}Restaurado com sucesso!${NC}"
            fi ;;
    esac
    sleep 2
}

# --- MENU PRINCIPAL ---

while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${AMARELO}CENTRAL DE BACKUP DA VPS${NC}"
    echo -e "  Operador: ${VERDE}$USER_REAL${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📦 Gerar Backup Local"
    echo -e "  [2] 🚀 Gerar e Enviar para outro Servidor"
    echo -e "  [3] 💻 Instruções para Baixar para seu PC"
    echo -e "  [4] 🔄 Restaurar Backup (Apenas Admin)"
    echo -e "  [5] ⬅️  Voltar"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) 
            gerar_backup
            read -p "Pressione ENTER para continuar..." d ;;
        2) 
            gerar_backup
            read -p " IP Remoto: " R_IP
            read -p " Usuário Remoto: " R_USER
            read -p " Pasta Destino: " R_DIR
            scp "$ARQUIVO_BACKUP" "${R_USER}@${R_IP}:${R_DIR}"
            read -p "ENTER..." d ;;
        3) 
            gerar_backup
            IP_PUB=$(curl -s --max-time 2 ifconfig.me)
            echo -e "\n${AMARELO}No terminal do seu computador, digite:${NC}"
            echo -e "${VERDE}scp $USER_REAL@$IP_PUB:$ARQUIVO_BACKUP ./ ${NC}\n"
            read -p "Pressione ENTER..." d ;;
        4) 
            restaurar_backup ;;
        5) 
            exit 0 ;;
        *) 
            sleep 1 ;;
    esac
done
