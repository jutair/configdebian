# ConfigDebian

Sistema de automação e gerenciamento para servidores Debian/Linux.

O **ConfigDebian** é uma coleção de scripts Bash desenvolvida para automatizar a configuração, manutenção e administração de servidores VPS baseados em Debian.

O projeto inclui ferramentas para:

* Instalação inicial da VPS;
* Atualização automática do sistema;
* Gerenciamento de usuários;
* Administração de rede e firewall;
* Configuração do OpenVPN;
* Monitoramento do servidor;
* Backup automatizado;
* Compartilhamento de arquivos via Samba.

---

## 🚀 Principais Recursos

✅ Configuração automática da VPS

✅ Atualização centralizada dos scripts

✅ Painel interativo via terminal

✅ Gerenciamento simplificado de usuários Linux

✅ Ferramentas de rede e firewall

✅ Configuração e administração do OpenVPN

✅ Sistema de monitoramento e alertas

✅ Rotinas de backup

✅ Compartilhamento de arquivos com Samba

---

## 📂 Estrutura do Projeto

| Script              | Descrição                                                      |
| ------------------- | -------------------------------------------------------------- |
| `setup_vps.sh`      | Instala e configura automaticamente o ambiente inicial da VPS. |
| `update_sistema.sh` | Atualiza os scripts e componentes do sistema.                  |
| `menu.sh`           | Painel principal de gerenciamento.                             |
| `usuarios.sh`       | Gerencia usuários locais do sistema.                           |
| `gerencia_rede.sh`  | Ferramentas de configuração de rede e firewall.                |
| `open_vpn_conf.sh`  | Configuração e manutenção do OpenVPN.                          |
| `client-connect.sh` | Executado quando clientes OpenVPN se conectam.                 |
| `guardiao.sh`       | Sistema de monitoramento e supervisão do servidor.             |
| `backup.sh`         | Rotinas automatizadas de backup.                               |

---

## 🖥️ Sistemas Suportados

* Debian 11
* Debian 12

Outras distribuições derivadas podem funcionar, porém não são oficialmente suportadas.

---

## 📥 Instalação

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

## 🔄 Atualização

Para atualizar os scripts:

```bash
sudo /opt/configdebian/update_sistema.sh
```

ou

```bash
bash update_sistema.sh
```

---

## 📋 Requisitos

* Debian 11 ou superior
* Acesso root ou sudo
* Conexão com a Internet

---

## 🛠️ Exemplo de Uso

Após a instalação:

```bash
menu
```

ou

```bash
bash /opt/configdebian/menu.sh
```

Será exibido o painel principal contendo todas as ferramentas administrativas.

---

## 🔒 Segurança

Este projeto modifica configurações críticas do sistema.

Recomenda-se:

* Utilizar em servidores de testes antes do ambiente de produção;
* Realizar backups antes de executar atualizações;
* Revisar os scripts antes da utilização.

---

## 📸 Capturas de Tela

*(Adicione aqui screenshots do menu principal e dos módulos.)*

---

## 🤝 Contribuições

Contribuições são bem-vindas.

1. Faça um Fork do projeto;
2. Crie uma branch:

```bash
git checkout -b minha-feature
```

3. Faça suas alterações;
4. Envie um Pull Request.

## 📄 Licença

Este projeto está licenciado sob a licença MIT.

Veja o arquivo `LICENSE` para mais informações.
