menu() {
    sudo ntpdate-debian
    IP_EXTERNO=$(curl -4 -s ifconfig.me || curl -4 -s ident.me)
    IP_INTERNO=$(hostname -I | awk '{print $1}')
    CURRENRT=$(logname 2>/dev/null || echo $SUDO_USER)

    while true; do
        clear
        HORA_ATUAL=$(date '+%H:%M:%S')
        DATA_ATUAL=$(date '+%d/%m/%Y')
      
        echo "================================================================="
        echo "                    MENU PRINCIPAL                               "
        echo "Usuário: $CURRENRT"
        echo "================================================================="
        echo "DATA: $DATA_ATUAL                           HORA: $HORA_ATUAL (MANAUS)"
        echo "IP Interno: $IP_INTERNO | IP Externo: $IP_EXTERNO"
        echo "================================================================="
        echo "Versão do script: 22/12/2025-3:18:57"
        echo "================================================================="
        echo ""
        echo "[1] Gerenciar Sistema        [6] Gerenciar usuários"
        echo "[2] Gerenciar Rede           [7] Atualizar o sistema"
        echo "[3] Ver logs do sistema      [8] Gerenciar OpenVpn"
        echo "[5] Fazer Backup             [9] Sair"
        echo ""
        
        echo -n "Digite a opção desejada: "
        # IMPORTANTE: Adicionamos o "|| true" para o read não encerrar o script em caso de timeout
        read -t 58 OPCAO || true

        # Usamos "$OPCAO" com aspas para garantir que o valor seja tratado como string única
        case "$OPCAO" in
            1) echo "Em desenvolvimento..." ; sleep 1 ;;
            2) gerencia_rede ;;
            6) exec ./usuarios.sh ;;
            7) update_sistema ;;
            8) exec ./open_vpn_conf.sh ;;
            9) 
                echo "Encerrando sistema..."
                kill -TERM -$(ps -o pgid= $PPID | grep -o '[0-9]*')
                exit 0
                sleep 10
                ;;
            "") # Quando o tempo de 58s acaba, ele apenas reinicia o loop
                continue 
                ;;
            *) 
                echo -e "\n\033[31mOpção inválida: '$OPCAO'\033[0m"
                sleep 1 
                ;;
        esac
    done
}
Implemente aqui na função
