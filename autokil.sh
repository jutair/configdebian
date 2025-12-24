#!/bin/bash
# auto_kill.sh - Monitor de Abuso de Recursos
# Este script encerra processos de utilizadores que excedam limites de CPU.

MAX_CPU=80  # Limite de 80% de CPU
LOG_FILE="/var/log/vps_autokill.log"

# Procura por processos de utilizadores normais (UID >= 1000)
# que estejam a usar muita CPU, ignorando o root.
ps -eo user,pid,pcpu,comm,uid --sort=-pcpu | awk -v max=$MAX_CPU '$5 >= 1000 && $3 > max {print $1, $2, $3, $4}' | while read USER PID CPU COMM; do
    
    # Regista o abuso no log
    echo "$(date "+%Y-%m-%d %H:%M:%S") - MATANDO: Utilizador $USER (PID: $PID) usando $CPU% CPU com o comando $COMM" >> $LOG_FILE
    
    # Envia um aviso para o terminal do utilizador (se ainda estiver aberto)
    wall "AVISO: Utilizador $USER, a sua sessão foi encerrada por excesso de uso de CPU ($CPU%)." 2>/dev/null
    
    # Mata o processo e encerra a sessão do utilizador
    kill -9 $PID
    pkill -u $USER -t pts/* 2>/dev/null
done
