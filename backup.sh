#!/bin/bash
# backup_geral.sh - Central de Backup e Restauração

# --- CORES ---
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
NC='\033[0m'

# --- CONFIGURAÇÕES ---
USER_ATUAL=$(logname 2>/dev/null || echo ${SUDO_USER:-$(whoami)})
DATA=$(date +%d-%m-%Y_%H-%M)
ARQUIVO_BACKUP="/tmp/backup_vps_${DATA}.tar.gz"

# 1. Função para Gerar Backup
gerar_backup() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERDE}GERANDO BACKUP COMPACTADO${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    
    # Criando lista de arquivos para backup
    echo -e "${AMARELO}[1/3]${NC} Coletando arquivos (SSH, Samba, OVPN)..."
    
    # Arquivos globais e pastas de backup dos usuários
    tar -czf "$ARQUIVO_BACKUP" \
        /etc/ssh/sshd_config \
        /etc/samba/smb.conf \
        /etc/openvpn \
        /home/*/Backup \
        2>/dev/null

    echo -e "${VERDE}[OK]${NC} Backup gerado em: $ARQUIVO_BACKUP"
    echo -e "${AZUL}===============================================================${NC}"
}

# 2. Função para Enviar para outro Servidor
enviar_servidor() {
    gerar_backup
    echo -e "${AMARELO}Configurações de Destino:${NC}"
    read -p " IP do Servidor Remoto: " REMOTE_IP
    read -p " Usuário Remoto: " REMOTE_USER
    read -p " Pasta de Destino (Ex: /home/backup): " REMOTE_DIR
    
    echo -e "${AMARELO}Enviando via SCP...${NC}"
    scp "$ARQUIVO_BACKUP" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}"
    
    if [ $? -eq 0 ]; then
        echo -e "${VERDE}Backup enviado com sucesso!${NC}"
    else
        echo -e "${VERMELHO}Erro no envio! Verifique as credenciais.${NC}"
    fi
    sleep 3
}

# 3. Função para Restaurar
restaurar_backup() {
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${VERMELHO}RESTAURAÇÃO DE SISTEMA${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e " [1] Restaurar de Arquivo Local"
    echo -e " [2] Buscar de Servidor Remoto"
    read -n 1 -p " Escolha: " OP_RES; echo ""

    case $OP_RES in
        1)
            read -p " Caminho completo do arquivo (.tar.gz): " CAMINHO
            if [ -f "$CAMINHO" ]; then
                tar -xzf "$CAMINHO" -C /
                echo -e "${VERDE}Configurações restauradas! Reiniciando serviços...${NC}"
                systemctl restart ssh samba openvpn 2>/dev/null
            else
                echo -e "${VERMELHO}Arquivo não encontrado!${NC}"
            fi ;;
        2)
            read -p " IP do Servidor: " R_IP
            read -p " Usuário: " R_USER
            read -p " Caminho no Servidor: " R_PATH
            scp "${R_USER}@${R_IP}:${R_PATH}" /tmp/restaura.tar.gz
            tar -xzf /tmp/restaura.tar.gz -C /
            echo -e "${VERDE}Restaurado com sucesso!${NC}" ;;
    esac
    sleep 3
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "                ${AMARELO}CENTRAL DE BACKUP DA VPS${NC}"
    echo -e "${AZUL}===============================================================${NC}"
    echo -e "  [1] 📦 Gerar Backup e Manter Local (/tmp)"
    echo -e "  [2] 🚀 Gerar e Enviar para Outro Servidor (SCP)"
    echo -e "  [3] 💻 Instruções para Baixar para PC Local"
    echo -e "  [4] 🔄 Restaurar Backup (Local ou Remoto)"
    echo -e "  [5] ⬅️  Voltar"
    echo -e "${AZUL}---------------------------------------------------------------${NC}"
    read -n 1 -p " Digite a opção: " OP; echo ""

    case $OP in
        1) gerar_backup; read -p "ENTER para continuar..." d ;;
        2) enviar_servidor ;;
        3) 
           gerar_backup
           echo -e "${AMARELO}Para baixar este arquivo no seu PC (Windows/Linux/Mac),${NC}"
           echo -e "${AMARELO}abra o terminal do seu computador e digite:${NC}"
           echo -e "\n${VERDE}scp root@$(curl -s ifconfig.me):$ARQUIVO_BACKUP ./ ${NC}\n"
           read -p "Pressione ENTER..." d ;;
        4) restaurar_backup ;;
        5) exit 0 ;;
    esac
done
