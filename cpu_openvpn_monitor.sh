#!/bin/bash

# Cores para o terminal
VERMELHO='\033[0;31m'
VERDE='\033[0;32m'
NC='\033[0m' # Sem cor

echo "Monitorando OpenVPN... (Pressione Ctrl+C para parar)"
echo "---------------------------------------------------"

while true; do
    # Pega o uso de CPU do processo openvpn
    CPU_USAGE=$(ps -C openvpn -o %cpu | tail -n 1 | tr -d ' ')
    
    # Compara se o uso está acima de 80% (exemplo de limite)
    if (( $(echo "$CPU_USAGE > 80.0" | bc -l) )); then
        echo -e "${VERMELHO}ALERTA: Uso de CPU alto! -> $CPU_USAGE%${NC}"
    else
        echo -e "${VERDE}Status OK: Uso de CPU -> $CPU_USAGE%${NC}"
    fi
    
    sleep 2
done
