# Pega o nome do primeiro usuário humano criado no sistema
USUARIO_HUMANO=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)
# Pega a home desse usuário
HOME_HUMANA=$(getent passwd "$USUARIO_HUMANO" | cut -d: -f6)
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPor favor execute esse script como sudo!"
  echo -e "\033[31msudo ./configura_sistema.sh"
  echo -e "\033[0m"
  exit 1
fi
echo -e "\033[0m" #Reseta as cores ao padão
# Variáveis de cores
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m' # Negrito e Amarelo
NC='\033[0m' # No Color / Reset
echo **********************************************************************************************************************
echo -e "${VERDE}Iniciando a configuração${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Inslatando o comando sudo${NC}"
echo **********************************************************************************************************************
apt install sudo -y
echo **********************************************************************************************************************
echo -e "${AMARELO}Atualizando o sistema${NC}"
echo **********************************************************************************************************************
sudo apt update && sudo apt upgrade -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando as ferramentas basicas do sistema${NC}"
sudo apt install htop -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes básicos de rede${NC}"
sudo apt install net-tools -y
echo -e "${VERDE}Instalando o Samba${NC}"
sudo apt install samba -y
echo -e "${VERDE}Instalando o Nload${NC}"
sudo apt install nload -y
echo -e "${VERDE}Instalando o IF-top${NC}"
sudo apt install iftop -y
echo -e "${VERDE}Instalando o Speedtest${NC}"
sudo apt install speedtest-cli -y
echo -e "${VERDE}Instalando o Vnstat${NC}"
sudo apt install vnstat -y
echo -e "${VERDE}Instalando o Syssat${NC}"
sudo apt install sysstat -y
echo -e "${VERDE}Instalando o TCPdump${NC}"
sudo apt install tcpdump -y
echo **********************************************************************************************************************
echo -e "${VERDE}Instalando os pacotes para SSH${NC}"
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
echo **********************************************************************************************************************
echo -e "${VERDE}Instalado o Firewall${NC}"
sudo apt install ufw -y
echo **********************************************************************************************************************
echo -e "${VERDE}Configurando o Firewall${NC}"
sudo ufw allow ssh
echo -e "${VERDE}Permitindo UDP na porta 1194${NC}"
sudo ufw allow 1194/udp
echo -e "${VERDE}Permitindo TCP na porta 4004${NC}"
sudo ufw allow 4004/tcp
echo -e "${Amarelo}Permitindo TCP na Porta 22${NC}"
sudo ufw allow 22/tcp
echo -e "${Amarelo}Iniciando Firewalll...${NC}"
sudo ufw enable
echo -e "${VERDE}Firewall Iniciado!${NC}"
echo **********************************************************************************************************************
echo -e "${VERDE}Criando os usuários${NC}"
####################################Apenas em servidor VPS#################################################################
echo **********************************************************************************************************************
# 1. Cria o usuário (se já não existir)
sudo useradd -G sudo -m jutair -s /bin/bash 2>/dev/null
echo "jutair:SUA_SENHA_AQUI"
sudo passwd jutair
# 2. Cria a pasta .ssh com o dono correto desde o início
sudo mkdir -p /home/jutair/.ssh

# 3. Tenta copiar a chave do root, mas verifica se ela existe primeiro
if [ -f /root/.ssh/authorized_keys ]; then
    sudo cp /root/.ssh/authorized_keys /home/jutair/.ssh/
    echo "✅ Chaves copiadas com sucesso de /root"
else
    echo "⚠️  Aviso: /root/.ssh/authorized_keys não existe. Criando arquivo vazio."
    sudo touch /home/jutair/.ssh/authorized_keys
fi

# 4. AJUSTE DE PERMISSÕES (O ponto mais importante)
# O dono deve ser o USUÁRIO, não o root. Se o dono for root, o SSH rejeita o login.
sudo chown -R jutair:jutair /home/jutair/.ssh
sudo chmod 700 /home/jutair/.ssh
sudo chmod 600 /home/jutair/.ssh/authorized_keys
echo "-------------------------------------------------------"
echo "✅ Usuário 'Jutair' configurado com sucesso."
echo "-------------------------------------------------------"
###########################################################################################################################
#!/bin/bash

# 1. Cria o usuário guest
# -m cria a home, -s define o shell padrão
sudo useradd -m -s /bin/bash guest 2>/dev/null
echo "guest:SENHA_AQUI"
sudo passwd guest
# 2. Configura o diretório SSH
sudo mkdir -p /home/guest/.ssh

# 3. Verifica e copia a chave autorizada do root
if [ -f /root/.ssh/authorized_keys ]; then
    sudo cp /root/.ssh/authorized_keys /home/guest/.ssh/
    echo "✅ Chaves copiadas para o usuário guest."
else
    echo "⚠️  Aviso: Nenhuma chave encontrada em /root. Criando arquivo vazio."
    sudo touch /home/guest/.ssh/authorized_keys
fi

# 4. Ajuste CRÍTICO de permissões
# O dono DEVE ser o guest para o SSH permitir o login
sudo chown -R guest:guest /home/guest/.ssh
sudo chmod 700 /home/guest/.ssh
sudo chmod 600 /home/guest/.ssh/authorized_keys

# 5. Confirmação de restrição
echo "-------------------------------------------------------"
echo "✅ Usuário 'guest' configurado com sucesso."
echo "-------------------------------------------------------"
echo **********************************************************************************************************************
echo -e "${VERDE}Fazendo BACKUP das configurações${NC}"
cd /home/jutair
mkdir -p Backup
cp /etc/ssh/sshd_config /home/jutair/Backup
cp /etc/samba/smb.conf /home/jutair/Backup
cd
echo **********************************************************************************************************************
echo -e "${VERDE}Copiando os scripts para a pasta do usuário Jutair${NC}"
cp -r $HOME_HUMANA/configdebian-main /home/jutair
echo -e "${VERDE}Copiando os scripts para a pasta do usuário Guest${NC}"
cp -r $HOME_HUMANA/configdebian-main /home/guest
echo Baixando os parâmetros do Servidor SSH
echo Baixando as confiurações do Samba
echo Baixando os scripts de backup
echo **********************************************************************************************************************
echo -e "${AMARELO}Saindo...${NC}"
echo -e "${AMARELO}Logue com o seu usuário${NC}"
echo -e "${VERMELHO}Scriptfinalizado${NC}"
cd
exit
exit

