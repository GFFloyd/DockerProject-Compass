# DockerProject-Compass
_Projeto de Docker - Compass.UOL_

---

## Introdução

A atividade pede que criemos algumas instâncias EC2 com o Wordpress conteinerizado dentro, estas instâncias do Wordpress vão se conectar ao serviço RDS da Amazon (mySQL) e os arquivos estáticos do Wordpress serão guardados em um EFS montado dentro da EC2. A atividade também pede que usemos o Load Balancer como ponto de entrada e a única parte da arquitetura aberta em uma subrede pública, o restante deve estar em subredes privadas e com Auto-Scalling para aumentar ou diminuir quantas instâncias EC2 devem estar rodando, dependendo de alguns gatilhos específicos. Como mostra a imagem abaixo:
![Topologia da Nuvem AWS que a atividade pede](imgs/image.png)

---

### Índice

[Primeiros Passos](##PrimeirosPassos)
[Criação da Instância EC2](###-criaçãodainstânciaec2)

---

## Primeiros Passos

### - Criação da Instância EC2



