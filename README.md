# Atividade de Docker na Nuvem AWS
_Projeto de Docker - Compass.UOL_

---

## Introdução

A atividade pede que criemos algumas instâncias EC2 com o Wordpress conteinerizado dentro, estas instâncias do Wordpress vão se conectar ao serviço RDS da Amazon (mySQL) e os arquivos estáticos do Wordpress serão guardados em um EFS montado dentro da EC2. A atividade também pede que usemos o Load Balancer como ponto de entrada e a única parte da arquitetura aberta em uma subrede pública, o restante deve estar em subredes privadas e com Auto-Scalling para aumentar ou diminuir quantas instâncias EC2 devem estar rodando, dependendo de alguns gatilhos específicos. Como mostra a imagem abaixo: 
![Topologia da Nuvem AWS que a atividade pede](imgs/image.png)

---

### Índice

[Primeiros Passos e Testes](#primeiros-passos-e-testes)
- [Criação da Instância EC2](#1-criação-da-instância-ec2)
- [Instalar o Docker na EC2](#2-instalar-o-docker-na-ec2)
- [Configurar o RDS](#3-configurar-o-rds)
- [Criar o Contêiner do Wordpress](#4-criar-o-contêiner-do-wordpress)

---

## Primeiros Passos e Testes

### 1. Criação da Instância EC2

O EC2 é um dos pilares da nuvem AWS, precisamos fazer rodar o Wordpress dentro de uma instância EC2, já que esta é a principal base do projeto. Para iniciarmos uma instância, vamos em **Launch Instances** (prefiro usar a AWS em inglês, então todos os comandos AWS desta documentação serão em inglês).   
Agora a AWS nos dá outra página, nela vamos ter que configurar algumas coisas:
- Em **Name and tags**, podemos colocar um par chave-valor específico nosso, somente para diferenciação de uma instância para outra.
- Em **Application and OS Images** vamos selecionar uma máquina Ubuntu, não tem problema de deixar no padrão da Amazon Linux, mas como eu tenho mais familiaridade com o Ubuntu, preferi deixar nela.
- Em **Instance Type** deixaremos na t2.micro, já que o Wordpress do projeto não precisará de muitos recursos.
- Em **Key Pair** iremos criar um par de chaves para acessarmos a instância via SSH (lembrar de colocar esta chave num diretório que você use mais, já que toda vez que formos acessar a EC2, você precisa estar no diretório de onde está esta chave).
- Em **Network Settings** deixaremos no padrão, por enquanto, no futuro iremos configurar as Security Groups.
- Em **Configure Storage** deixaremos o padrão de 8GB gp3.
- Em **Advanced Details** não mexeremos em nada, por enquanto, mas no futuro é onde iremos inserir o user_data.sh. 

Feito tudo isto, devemos esperar alguns momentos para que a máquina esteja pronta para uso.

### 2. Instalar o Docker na EC2

Precisamos entrar na EC2, onde você baixou a chave key.pem (da parte de Key Pair acima) é de onde iremos acessar a máquina via SSH com o seguinte comando:
```bash
ssh -i "nome do arquivo da chave".pem ubuntu@"ipv4 público da Instância EC2"
 ``` 
 _Obs. Se usássemos uma máquina AMI Linux, teríamos que substituir o ubuntu do comando acima para ec2user._
Dentro da instância EC2 precisaremos baixar o docker, para isso, a documentação do docker pede que rodemos alguns comandos extensos, um para adicionar a chave oficial GPG do Docker:
``` bash
apt-get update
apt-get install ca-certificates curl
mkdir -p /etc/apt/keyrings /dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
``` 
E outro para adicionar o repositório às fontes do apt:
``` bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
```
Feito estes comandos, agora iremos baixar o docker, containerd e suas dependências:
``` bash
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Para evitar que o Docker funcione somente com acesso de root, devemos colocar o seguinte comando e depois resetar a instância para termos acesso ao Docker sem precisarmos usar o comando sudo antes de qualquer comando do docker:
``` bash
usermod -aG docker ubuntu
``` 
Agora já podemos instalar a imagem do Wordpress e fazer ele rodar, mas antes, temos que configurar o Banco de Dados, para que o Wordpress funcione corretamente. Neste projeto iremos usar o banco de dados MySQL do RDS (Relational Database Service) que a Amazon disponibiliza para nós, vamos então configurar o mesmo na próxima sessão.

### 3. Configurar o RDS

Na parte de RDS da AWS, iremos clicar em **Create database**, na página seguinte iremos mudar algumas coisas:
- Em **Choose a database creation method** não iremos mudar.
- Em **Engine Options** iremos escolher o MySQL.
- Em **Templates** iremos escolher free tier, já que o serviço RDS é bastante caro.
- Em **Availability and durability** não temos como mudar nada.
- Em **Settings** mudaremos o _**DB Instance modifier**_ para algum identificador único, depois em _**Credential settings**_ daremos um nome para o usuário mestre do banco de dados e depois colocaremos uma senha segura.
- Em **Instance configuration** iremos mudar apenas a parte de selecionar qual máquina será alocada para o RDS, iremos colocar o db.t3.micro.
- Em **Storage** não mudaremos nenhuma configuração.
- Em **Connectivity** não mudaremos nada ainda, mas no futuro, iremos colocar que ela deverá funcionar em uma nova VPC, onde iremos configurar uma topologia específica ao projeto.
De resto, não precisaremos mexer em mais nada, podemos apertar em Create database.
Teremos que esperar algum tempo para que o banco de dados funcione.

Para que o EC2 tenha acesso ao RDS teremos que mudar uma configuração no Security Group atual, teremos que editar as Inbound Rules no SG que estamos usando e especificar que queremos que as EC2 consigam acessar o MySQL pela porta 3306, como na imagem abaixo:
![alt text](imgs/image2.png)
Agora já temos tudo necessário para que a instância EC2 tenha conexão com o RDS, o que possibilita que o Wordpress funcione.

### 4. Criar o contêiner do Wordpress








