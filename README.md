# ConfigDebian

Sistema completo para automação, monitoramento e gerenciamento de servidores Debian/Linux.

O **ConfigDebian** transforma uma instalação padrão do Debian em uma plataforma interativa de administração de VPS, oferecendo um painel centralizado para gerenciamento de usuários, OpenVPN, segurança, monitoramento, backup e manutenção do servidor.

Após a instalação, o painel administrativo é iniciado automaticamente sempre que um usuário acessa o servidor via SSH.

---

## 🌐 Requisitos de Rede

Caso o ConfigDebian seja instalado em um computador ou servidor localizado em sua residência, será necessário configurar o roteador para encaminhar as portas utilizadas pelo sistema.

As seguintes portas devem estar encaminhadas para o servidor:

* **22/TCP** → SSH (acesso remoto);
* **1194/UDP** → OpenVPN (VPN padrão).

Sem o encaminhamento dessas portas:

* O acesso SSH pela Internet não funcionará;
* Clientes externos não conseguirão conectar-se à VPN.

Exemplo:

```text
Internet
    ↓
Roteador Residencial
    ├── Porta 22/TCP   → Servidor Debian
    └── Porta 1194/UDP → Servidor Debian
```

### VPS em Nuvem

Em provedores como:

* DigitalOcean
* AWS
* Microsoft Azure

normalmente não é necessário configurar Port Forwarding, pois a VPS já possui um endereço IP público.

Entretanto, é necessário liberar as portas no firewall do provedor (Security Groups, Firewall ou Network Security Groups).

---

## 🚀 Recursos

* Instalação automatizada da VPS;
* Painel administrativo interativo em modo texto;
* Inicialização automática do painel após login SSH;
* Dashboard em tempo real;
* Gerenciamento completo do OpenVPN;
* Administração de usuários Linux e Samba;
* Gerenciamento avançado de rede e segurança;
* Sistema de backup e restauração;
* Atualização centralizada dos scripts;
* Monitoramento contínuo do servidor;
* Integração com Telegram para alertas;
* Modo manutenção protegido;
* Proteção contra acessos não autorizados.

---

## 🖥️ Sistemas Operacionais Suportados

* Debian 11
* Debian 12

Distribuições derivadas podem funcionar, porém não são oficialmente suportadas.

---

## 📦 Instalação

### Instalação rápida

```bash
wget https://raw.githubusercontent.com/jutair/configdebian/main/setup_vps.sh

chmod +x setup_vps.sh

sudo ./setup_vps.sh
```

ou

```bash
curl -O https://raw.githubusercontent.com/jutair/configdebian/main/setup_vps.sh

chmod +x setup_vps.sh

sudo ./setup_vps.sh
```

---

## ⚙️ Processo de Instalação

Durante a execução do `setup_vps.sh`, o sistema realiza automaticamente:

1. Verificação de privilégios administrativos;
2. Cadastro do Administrador e Operador;
3. Configuração opcional do Telegram;
4. Criação da estrutura de diretórios;
5. Instalação das dependências do sistema;
6. Configuração automática do fuso horário;
7. Download dos módulos diretamente do GitHub;
8. Criação dos usuários Linux;
9. Configuração do SSH;
10. Configuração da inicialização automática do painel;
11. Aplicação das políticas de segurança;
12. Inicialização do sistema Guardião.

### Estrutura criada

```text
/opt/configdebian
/etc/vps_protecao
```

### Arquivos de configuração

```text
/etc/vps_protecao/admin.conf
/etc/vps_protecao/telegram.conf
```

---

## 🔄 Fluxo de Funcionamento

```text
Instalação
     ↓
Configuração Automática
     ↓
Login SSH
     ↓
Inicialização do Menu
     ↓
Administração da VPS
```

---

# 🖥️ Painel Administrativo (`menu.sh`)

O `menu.sh` é o núcleo do ConfigDebian.

Sempre que um usuário acessar a VPS via SSH, o painel será iniciado automaticamente.

## Menu Principal

```text
[1] Dashboard em Tempo Real
[2] Gerenciar OpenVPN
[3] Rede & Segurança
[4] Gerenciar Usuários
[5] Atualizar Sistema / Painel
[6] Backup e Restauração
[8] Manutenção (Admin)
[0] Sair
```

---

## 📊 Dashboard

Exibe informações em tempo real:

### Sistema

* Data e hora;
* Endereço IP público;
* Uptime.

### Recursos

* Utilização da CPU;
* Consumo de memória RAM;
* Espaço em disco.

### Rede

* Tráfego da interface principal;
* Tráfego da VPN.

### Conexões

* Clientes OpenVPN conectados;
* Sessões SSH ativas.

### Segurança

* Quantidade de banimentos;
* Eventos registrados pelo Guardião.

---

# 🔐 Gerenciamento OpenVPN (`open_vpn_conf.sh`)

Módulo responsável pela instalação e administração completa da infraestrutura OpenVPN.

## Funcionalidades

### Instalação

* Instalação automática do servidor OpenVPN;
* Configuração de portas e protocolos;
* Configuração de NAT e roteamento;
* Definição de DNS para clientes.

### Clientes VPN

* Criar clientes;
* Revogar clientes;
* Excluir clientes;
* Gerar arquivos `.ovpn`;
* Consultar clientes cadastrados.

### Monitoramento

* Clientes conectados;
* IP remoto;
* IP VPN atribuído;
* Tempo de conexão;
* Estatísticas de tráfego.

### Serviço OpenVPN

* Iniciar serviço;
* Parar serviço;
* Reiniciar serviço;
* Consultar status.

### PKI

* Gerenciamento da CA;
* Certificados;
* Chaves privadas;
* Lista de certificados revogados (CRL).

---

# 🌐 Rede e Segurança (`gerencia_rede.sh`)

## Menu Principal

```text
[1] Logs do Sistema
[2] Firewall e Segurança
[3] Testar Velocidade
[4] SSH Config (Admin)
[5] VnStat (Consumo)
[6] Alerta Telegram (Admin)
[7] Restaurar Segurança Padrão
[0] Voltar
```

---

## 📄 Logs do Sistema

Permite visualizar:

* Logs de autenticação;
* Logs do sistema;
* Logs SSH;
* Eventos de segurança.

---

## 🛡️ Firewall e Segurança

Permite:

* Banir IP manualmente;
* Desbanir IP;
* Consultar IPs bloqueados;
* Monitorar Fail2Ban;
* Gerenciar whitelist;
* Diagnosticar ataques SSH.

Arquivo da whitelist:

```text
/etc/vps_protecao/whitelist.conf
```

---

## ⚡ Teste de Velocidade

Executa testes utilizando:

```bash
speedtest-cli
```

Exibindo:

* Download;
* Upload;
* Latência.

---

## 🔐 SSH Config (Admin)

Disponível apenas para o Administrador principal.

Arquivo gerenciado:

```text
/etc/ssh/sshd_config
```

### Funcionalidades

#### Alterar Porta SSH

* Modifica a porta do serviço SSH;
* Atualiza automaticamente o firewall;
* Reinicia o serviço SSH.

#### Permitir/Bloquear Login Root

Permite configurar:

```text
PermitRootLogin yes
PermitRootLogin no
PermitRootLogin prohibit-password
```

#### Ativar/Desativar Autenticação por Senha

Permite configurar:

```text
PasswordAuthentication yes
PasswordAuthentication no
```

#### Desconectar Usuários Ativos

Permite:

* Listar sessões SSH;
* Visualizar IPs conectados;
* Encerrar sessões específicas.

#### Visualizar Sessões SSH

Exibe:

* Usuário;
* Endereço IP;
* Horário do login;
* Terminal utilizado.

#### Reiniciar Serviço SSH

Executa:

```bash
systemctl restart ssh
```

#### Verificar Configuração Atual

Exibe:

* Porta atual;
* Status do login root;
* Status da autenticação por senha.

---

## 📈 Monitoramento de Consumo

Utiliza:

```bash
vnstat
```

Exibe:

* Consumo diário;
* Consumo mensal;
* Tráfego recebido;
* Tráfego transmitido.

---

## 📨 Configuração do Telegram

Permite configurar:

* Token do Bot Telegram;
* Chat ID.

Arquivo:

```text
/etc/vps_protecao/telegram.conf
```

---

## 🔄 Restaurar Segurança Padrão

Executa automaticamente:

* Reset do UFW;
* Reconfiguração do SSH;
* Reaplicação das regras de firewall;
* Reinicialização do Guardião;
* Reconfiguração do NTP.

---

# 👥 Gerenciamento de Usuários (`usuarios.sh`)

Permite:

* Criar usuários Linux;
* Excluir usuários;
* Alterar senhas;
* Gerenciar grupos;
* Configurar acesso SSH;
* Gerenciar usuários Samba;
* Auditoria de usuários.

---

# 🔄 Atualização do Sistema (`update_sistema.sh`)

Responsável por:

* Atualizar scripts;
* Sincronizar arquivos com o GitHub;
* Aplicar correções e melhorias.

Atualização manual:

```bash
sudo /opt/configdebian/update_sistema.sh
```

---

# 💾 Backup e Restauração (`backup.sh`)

Permite:

* Criar backups;
* Restaurar backups;
* Preservar configurações críticas;
* Facilitar migração entre servidores.

---

# 🛠️ Modo Manutenção

Disponível através da opção:

```text
[8] Manutenção
```

Características:

* Acesso direto ao shell Linux;
* Restrito ao Administrador principal;
* Acesso irrestrito para `root`;
* Registro de eventos;
* Integração com Telegram.

Tentativas de acesso não autorizadas podem:

* Ser registradas;
* Gerar alertas via Telegram;
* Encerrar automaticamente sessões SSH.

---

# 🔒 Segurança

O ConfigDebian implementa diversas medidas de proteção:

* Controle de acesso administrativo;
* Firewall centralizado;
* Proteção contra Fork Bomb;
* Monitoramento contínuo;
* Registro de eventos;
* Proteção contra esgotamento de memória;
* Encerramento automático de acessos não autorizados.

---

## 📁 Estrutura do Projeto

```text
configdebian/
├── setup_vps.sh
├── menu.sh
├── usuarios.sh
├── gerencia_rede.sh
├── open_vpn_conf.sh
├── update_sistema.sh
├── backup.sh
├── guardiao.sh
├── client-connect.sh
├── README.md
└── LICENSE

---

## 📋 Requisitos

* Debian 11 ou superior;
* Acesso root ou sudo;
* Conexão com a Internet.

---

## 🤝 Contribuições

Contribuições são bem-vindas.

1. Faça um Fork do projeto;
2. Crie uma branch:

```bash
git checkout -b minha-feature
```

3. Faça suas alterações;
4. Realize commit das modificações;
5. Envie um Pull Request.
---

## 📄 Licença

Este projeto está licenciado sob a licença MIT.

Consulte o arquivo `LICENSE` para mais informações.
