#!/bin/bash
cd /tmp
wget -q https://github.com/jutair/configdebian/archive/refs/heads/main.zip
unzip -o main.zip
chmod +x configdebian-main/configura_sistema.sh
./configdebian-main/configura_sistema.sh
rm -rf /tmp/main.zip /tmp/configdebian-main
rm -- "$0"  
