# Atividade de Docker na Nuvem AWS
_Projeto de Docker - Compass.UOL_

---

## Introdução

A atividade pede que criemos algumas instâncias EC2 com o Wordpress conteinerizado dentro, estas instâncias do Wordpress vão se conectar ao serviço RDS da Amazon (mySQL) e os arquivos estáticos do Wordpress serão guardados em um EFS montado dentro da EC2. A atividade também pede que usemos o Load Balancer como ponto de entrada e a única parte da arquitetura aberta em uma subrede pública, o restante deve estar em subredes privadas e com Auto-Scaling para aumentar ou diminuir quantas instâncias EC2 devem estar rodando, dependendo de alguns gatilhos específicos. Como mostra a imagem abaixo: 
    
![Topologia da Nuvem AWS que a atividade pede](imgs/image.png)

---

### Índice

[Primeiros Passos e Testes](#primeiros-passos-e-testes)
- [1. Criação da Instância EC2](#1-criação-da-instância-ec2)
- [2. Instalar o Docker na EC2](#2-instalar-o-docker-na-ec2)
- [3. Configurar o RDS](#3-configurar-o-rds)
- [4. Criar o Contêiner do Wordpress](#4-criar-o-contêiner-do-wordpress)
- [5. Criar a EFS e Conectá-la à EC2](#5-criar-uma-efs-e-conectá-la-à-ec2)

[Próximos Passos](#próximos-passos)
- [1. Criar uma VPC](#1-criar-uma-vpc)
- [2. Criar as Sub-redes](#2-criar-as-sub-redes)
- [3. Criar as Tabelas de Rotas e Internet Gateway](#3-criar-as-tabelas-de-rotas-e-internet-gateway-vinculá-las-às-sub-redes)
- [4. Criação dos Security Groups](#4-criação-dos-security-groups)
- [5. Criar uma Nova RDS e EFS dentro da Nova VPC](#5-criar-uma-nova-rds-e-efs-dentro-da-nova-vpc)

[Criação do Template e User Data](#criação-do-template-e-user-data) 

[Criação do NAT Gateway e Load Balancer](#criação-do-nat-gateway-e-load-balancer) 

[Criação do Auto-Scaling](#criação-do-auto-scaling)

[Conclusão Final](#conclusão)

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
![Imagem de exemplo do RDS](imgs/image2.png)
Agora já temos tudo necessário para que a instância EC2 tenha conexão com o RDS, o que possibilita que o Wordpress funcione.

### 4. Criar o contêiner do Wordpress

Agora que temos acesso ao RDS, vamos entrar na instância EC2 que tem o docker e fazer o contêiner do Wordpress, iremos usar o **docker compose** para facilitar o processo de construção do contêiner.
Dentro da EC2 vamos dar o seguinte comando: 
```bash 
sudo vim docker-compose.yaml
``` 
Nele, iremos escrever o manifesto que o docker compose usará para criar o Wordpress e fazer as conexões com o banco de dados, como a seguir:
```yaml
services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: <db-host>
      WORDPRESS_DB_USER: <db-user>
      WORDPRESS_DB_PASSWORD: <db-pwd>
      WORDPRESS_DB_NAME: <db-name>
    volumes:
      - /efs/wordpress:/var/www/html
```
_Obs: Onde há aquelas variáveis de ambiente do banco de dados, você deverá colocar os valores atuais para o seu caso._ 

Vamos salvar o arquivo e sair (esc + :wq no vim)
Agora que temos o manifesto yaml pronto, iremos usar o docker para construir o contêiner, usaremos o seguinte comando no diretório que você colocou o arquivo docker-compose.yaml:
```bash
docker compose up -d
```
Se tudo ocorreu bem, o docker dirá que construir o contêiner mais uma rede própria do contêiner. Caso não tenha dado certo até aqui, recomendo ir na documentação do docker e ver se há algum problema com a instação ou com o docker compose: [Documentação do Docker](https://docs.docker.com/reference/).

Agora podemos pegar o IP público da EC2 e entrar na porta 8080 e ver se iremos ser recebidos por esta imagem:
![Wordpress Install](imgs/wordpressInstall.png)

_Obs: Um problema comum desta parte é o Wordpress avisar que não pôde fazer uma conexão com o Banco de Dados, resolução mais comum desse problema é alguma credencial errada no yaml file ou no Security Group, se tiver com este problema, recomendo dar uma revisada nestas partes_

Agora que temos um Wordpress funcional, iremos criar uma conexão da instância EC2 do Wordpress com o EFS (Elastic File System), para o Wordpress pegar seus arquivos estáticos independente do armazenamento das EC2.

### 5. Criar uma EFS e conectá-la à EC2.

Para criar um EFS é muito simples, apenas temos que dar um nome e dizer qual VPC queremos que ele use. Como estamos ainda na VPC Default, só iremos colocar um nome.

Agora temos um EFS para montarmos em nossa EC2 do Wordpress, vamos entrar na EC2 e dar o seguinte comando para iniciarmos o processo de montagem do EFS lá:
```bash
sudo apt update -y
sudo apt install nfs-common
```
O serviço nfs-common é necessário para montar file systems no Ubuntu, precisaremos dele, depois que ele estiver instalado, é hora de montarmos o EFS na máquina, teremos que ir na página da EFS e clicar em **Attach**.
Vamos copiar um dos comandos que ele descreve para gente, parecido com este abaixo:
```bash
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <endereço de DNS para o EFS vai aqui>:/ /efs
```
Dentro da EC2 devemos colar este comando e se tudo der certo, com o ```df -h``` ele mostrará como um dos file systems montados no sistema. Agora o diretório /efs servirá como o volume onde o Wordpress irá salvar seus arquivos estáticos.

_Obs: Se caso tenha erro nesta parte, provavelmente é algum erro da nfs-common ou de alguma configuração do EFS, como o Security Group._

---

## Próximos Passos

### 1. Criar uma VPC

Como a arquitetura proposta pede que criemos algumas sub-redes públicas e privadas, ficaria melhor criarmos uma VPC nossa, apesar que a AWS já cria uma default com tudo configurado.
Para criarmos uma VPC é muito simples, vamos seguir alguns passos:
* Em **Name tag** daremos um nome único para a VPC.
* Na parte de **IPv4 CIDR** criaremos um bloco de IP para nossa rede interna, dá para criar com o que ele dá de exemplo: 10.0.0.0/16.
_Obs: É bom lembrarmos deste IP, pois usaremos em algumas configurações_

De resto, não precisaremos mudar nenhuma opção, só criar a VPC.

### 2. Criar as Sub-redes.

Vamos criar agora as quatro sub-redes dentro da VPC que acabamos de criar (duas públicas e duas privadas), vamos criar a sub-rede pública de exemplo e as outras três é só repetir os passos:

* Temos que especificar qual VPC iremos criar a sub-rede, importante selecionar a nova VPC.
* Em **Subnet name** colocaremos o nome desta sub-rede, por exemplo: subnet-public-1.
* Em **Availability zone** vamos especificar que queremos na us-east-1a.
* Em **IPv4 VPC CIDR block** especificaremos aquele bloco que vimos na parte anterior: 10.0.0.0/16.
* Em **IPv4 subnet CIDR block** iremos especificar o range de IPs que usaremos para esta sub-rede, vamos usar o 10.0.0.0/24 (Nas sub-redes posteriores iremos incrementar o terceiro octeto da faixa de IPs para não dar _overlap_).
* Faremos os mesmos passos nas outras 3 sub-redes.

### 3. Criar as Tabelas de Rotas e Internet Gateway, Vinculá-las às Sub-redes.

Esta parte é simples, apenas dar um nome para a tabela de rotas, exemplo: public-route-table.
Depois temos que criar um Internet gateway, que também é só dar um nome, exemplo: wordpress-internet-gateway.
Agora temos que vincular estes itens novos às sub-redes públicas e privadas.
Para fazer isso seguiremos alguns passos:
* Em **Route Tables** iremos na public-route-table que criamos anteriormente e vamos em **Subnet Associations**.
* Vamos vincular explicitamente as sub-redes que queremos no botão **Edit subnet associations**, ali clicaremos nas sub-redes que queremos vincular à tabela de rotas.
* Faremos o mesmo processo para a outra tabela de rotas privada.
* Agora iremos associar a sub-rede pública ao internet gateway, vamos em **Routes** e clicaremos no botão **Edit routes**, ali vincularemos o gateway à essa sub-rede.
Por enquanto a sub-rede privada não vai ter um gateway, vai ficar isolado da internet, no futuro iremos criar um NAT gateway para que as instâncias privadas consigam baixar pacotes da internet.
Se tudo deu certo, a topologia deve estar assim:
![topologia](imgs/vpcnetwork.png)

### 4. Criação dos Security Groups

Agora que criamos esta nova rede, precisamos vincular a elas alguns Security Groups novos, para configurarmos algumas **Inbound Rules** específicas para cada uma.
Vamos em **Security Groups** na barra de pesquisa, lá vamos clicar no botão **Create security group**, estando lá vamos seguir alguns passos:
* Dar um nome a ela, no caso estamos fazendo a Security Group pública, então colocarei public-sg como nome de exemplo.
* Selecionaremos a VPC nova, ela deixa a default por padrão.
* Iremos criar algumas **Inbound Rules** para esta SG:
  Como este será o SG público, podemos ser um pouco permissivos nas regras, iremos adicionar regras para HTTP, HTTPS, SSH e que aceitem _**Anywhere-IPv4**_, somente nas regras de NFS e MySQL/Aurora que iremos especificar que queremos que só IPs da VPC possam acessar estes serviços, temos que especificar o **_CIDR Block_** que colocamos anteriormente (10.0.0.0/16);
  _Obs: Na criação de SG privado iremos ser mais cautelosos nestas regras de entrada._
*  Agora é só salvar este SG no botão **Create security group**
* Faremos o mesmo para o SG privado, mas na parte de criação de **Inbound Rule** iremos especificar algumas coisas:
  Vamos criar as mesmas regras para NFS, HTTP, HTTPS, SSH, MySQL/Aurora e especificar o Bloco CIDR da VPC para que somentes máquinas com aquele IP possam conectar aos serviços especificados. Vamos também criar uma regra TCP personalizada, que escuta na porta 8080, para ser o ponto de entrada do Wordpress, deixaremos também o bloco CIDR da VPC em _Source_.

### 5. Criar uma Nova RDS e EFS Dentro da Nova VPC

Bom lembrar que teremos que criar novos serviços de RDS e EFS dentro desta nova VPC, pois os serviços anteriores estão vinculados à VPC Default, seguir novamente os passos de criação de **[RDS](#3-configurar-o-rds)** e **[EFS](#5-criar-uma-efs-e-conectá-la-à-ec2)** (nesta parte de EFS não precisamos vincular ela a uma instância EC2 ainda) e mudar para a nova VPC e configurar para que elas sejam vinculadas aos **Security Groups**.

---

## Criação do Template e User Data

Agora que temos a topologia da rede que foi proposta pela atividade, podemos começar a automatização da instância EC2, para que a EC2 baixe tudo que é necessário quando for instanciada e que não precisemos entrar na instância toda vez para configurá-la.
Para isso, usaremos o serviço de **Launch Templates** dentro da sessão **EC2**.

_Obs: É bom frisar que agora iremos criar as instâncias na sub-rede privada, já que esta é a proposta do projeto e iremos apenas criar o Load Balancer na sub-rede pública, para que as EC2 privadas tenham como baixar pacotes da internet, deveremos criar um NAT Gateway para eles, veremos isso mais a frente_

Clicaremos em **Create launch template** e seguiremos o passo a passo abaixo:
* Em **Launch template name and version description** daremos um nome para este template e uma descrição breve. Marcaremos também a opção de **Provide guidance to help me set up a template that I can use with EC2 Auto Scaling** para ajudar em quais partes serão necessárias para o serviço de Auto Scaling.
* Em **Application and OS Images** iremos especificar que queremos Ubuntu.
* Em **Instance Type** vamos colocar t2.micro mesmo.
* Em **Key Pair** especificaremos o par de chaves que já criamos anteriormente.
* Em **Network Settings** colocaremos o Security Group privado que criamos anteriormente. Ainda nesta parte clicaremos em **Advanced network settings**,clicaremos em **Add network interface** deixaremos do jeito que está, só mudaremos na parte que diz **Auto assign public IP** e selecionaremos **Disable**.
* Em **Storage** deixaremos do jeito padrão.
* Em **Resource Tags** colocaremos algum par de chave-valor que podemos usar para identificarmos as EC2, exemplo InstanceName com o valor Wordpress1.
* E, finalmente, em Advanced Details iremos colocar um script BASH no final (em **User data - optional**), onde queremos especificar o que a EC2 deve fazer ao iniciar, que é chamado de user_data.sh, como já fizemos alguns comandos anteriormente, podemos compilar todos aqueles comandos em um só arquivo, para automatizar que a instância baixe o Docker, alguns pacotes do ubuntu, criar o contêiner via Docker Compose e já montar a EFS na máquina, para não colocar aqui e ficar muito extenso, este arquivo compilado pode ser checado neste repositório, com o nome **[user_data.sh](user_data.sh)**.
* Agora podemos clicar em **Create launch template** e finalizar o processo.

Não iremos usar ele ainda, pois precisamos ainda configurar o Load Balancer e o Auto-Scaling, que veremos a seguir.

---

## Criação do NAT Gateway e Load Balancer

Antes de criarmos o Load Balancer, vamos criar um NAT Gateway, para que as futuras instâncias EC2 privadas tenham conectividade para baixar os pacotes quando forem instanciadas, vamos em **VPC** e em **NAT Gateways** clicaremos no botão **Create NAT gateway**.
* Daremos um nome a esta NAT Gateway, por exemplo, project-nat-gateway.
* Especificaremos qual sub-rede que este NAT gateway vai ficar, temos que colocar ela numa das sub-redes públicas.
Feito isto, clicaremos em **Create NAT Gateway**.

Agora temos que associar esse NAT Gateway à sub-rede privada, iremos lá em **VPC**, clicaremos na sub-rede privada e iremos em **Routes**, nesta sessão cliquemos no botão **Edit routes**, ali vincularemos o NAT Gateway à sub-rede privada, feito isto, salvaremos.
Agora quando criarmos instâncias EC2 privadas, elas podem se comunicar com a internet.

Vamos criar o Load Balancer agora, em **EC2**, tem a sessão de **Load Balancers**, clicaremos no botão **Create load balancer** e seguiremos os passos:
* Vamos em **Classic Load Balancer** e clicar em **Create**.
* Daremos um nome para o LB, exemplo, project-load-balancer.
* Em **Scheme** deixaremos o padrão.
* Em **Network Mapping** vamos escolher a VPC nova, em **Mappings** especificaremos quais **_Availability Zones_** queremos que o Load Balancer roteie as conexões. Vamos colocar nas duas AZ públicas que criamos anteriormente (us-east-1a e us-east-1b).
* Em **Security Groups** colocaremos o SG público criado antes.
* Em **Listeners and Routing** deixaremos como está, já que nosso Wordpress está configurado para escutar na porta 80.
* Em **Health Checks** deixaremos o ping na porta 80, mas vamos especificar que o _**Ping path**_ vai ser no diretório /wp-admin/install.php.
* De resto não mudaremos nada e podemos clicar em **Create load balancer**.

Agora o Load Balancer servirá de interface entre os usuários e as instâncias EC2, podendo balancear a carga para uma ou outra instância, na próxima sessão iremos tratar do Auto-Scaling, que poderá aumentar automaticamente as instâncias, dependendo do consumo de recursos das EC2 disponíveis.

---

## Criação do Auto-Scaling

Vamos agora tratar de uma das partes finais do projeto, que é o Auto-Scaling, para isso, vamos em **EC2** e em **Auto Scaling Groups** clicaremos em **Create auto scaling group**, vamos seguir alguns passos para a criação do mesmo:
* Passo 1 - Em **Choose Launch Template** vamos escolher o template que criamos antes, para servir de base para as máquinas que serão criadas automaticamente pelo AS.
* Passo 2 - Em **Choose Instance Launch Options**, na parte de **Network** iremos especificar a VPC nova e especificar as sub-redes e AZs que o Auto Scaling irá gerenciar (iremos escolher a us-east-1a e a us-east-1b, só que nas sub-redes privadas), deixaremos marcado **Balanced best effort**.
* Passo 3 - Em **Integrate with other Services** iremos especificar que vamos vincular o Auto Scaling ao Load Balancer criado anteriormente clicando na opção **Attach to an existing load balancer**. Em **Existing load balancer target groups** iremos especificar as AZs e sub-redes vinculadas. Em **Health Checks** iremos clicar na caixa que diz **_Turn on Elastic Load Balancing health checks_**.
* Passo 4 - Em **Configure group size and scaling** iremos definir qual a capacidade desejada do Auto Scaling, colocaremos 2, como pede a atividade. Em **Scaling** iremos colocar o **Min desired capacity** como 2 e **Max desired capacity** como 4. De resto deixaremos padrão.
* Vamos passar pelas outras etapas e no final clicar em **Create auto scaling group** para finalizarmos.

Se tudo deu certo, o Auto Scaling irá criar duas instâncias EC2 que já estão configuradas para baixar o Docker e configurar o Wordpress baseado no Docker Compose.
O Load Balancer irá fazer uns Health checks nestas instâncias e, se tudo ocorreu bem, já poderemos acessar o DNS do Load Balancer e ver o Wordpress funcionando ao vivo na web, que era a proposta do projeto.

---

## Conclusão

Fico imensamente agradecido da **Compass.UOL** nos dar esta oportunidade para praticarmos a fundo como criar uma infraestrutura na AWS, um serviço que é custoso e que teríamos problema para praticarmos se fôssemos pagar do nosso próprio bolso, por receio dos custos. 
Aprendi muito nestas duas semanas de projeto, sendo que antes não tinha mexido muito com os serviços da AWS e hoje já me sinto confiante em alguns serviços, graças a este projeto.
Muito obrigado.

