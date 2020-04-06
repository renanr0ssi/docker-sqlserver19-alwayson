#Baixar imagem de SQL Server 2019 com Ubuntu 18.04:
FROM mcr.microsoft.com/mssql/server:2017-CU19-ubuntu-16.04

# Atualiza a imagem com os pacotes
RUN apt-mark hold msodbcsql17
RUN apt-get update && apt-get upgrade -y
RUN apt-get install iputils-ping -y
RUN apt-get install nano -y

#Aceite dos termos do SQL Server, seta senha do user SA e utiliza a licença de Dev:
ENV ACCEPT_EULA=Y
ENV SA_PASSWORD="PaSSw0rd"
ENV MSSQL_PID=Developer

#Desativa o Firewall para melhor funcionamento do Pacemarker:
#RUN apt-get install ufw -y
#RUN ufw disable

#Instala Pacemaker:
RUN apt-get install pacemaker pcs fence-agents resource-agents -y

#Trocar senha do Pacemaker:
#RUN passwd hacluster

#Inicia serviços do Pacemaker:
RUN systemctl enable pcsd
#RUN systemctl start pcsd
RUN systemctl enable pacemaker

#informa o Mantenedor dessa imagem que criaremos (Você pode colocar seu prórpio nome):
LABEL MAINTAINER="Renan Rossi"

#Cria as Variáveis e define o local dos Certificados (Veja como criar os seus no arquivo Readme.md)
ENV CERTFILE "certificate/dbm_certificate.cer"
ENV CERTFILE_PWD "certificate/dbm_certificate.pvk"
#Cria o diretório e copia os certificados para dentro desse diretório:
RUN mkdir /usr/certificate
WORKDIR /usr/
COPY ${CERTFILE} ./certificate
COPY ${CERTFILE_PWD} ./certificate

#Expor as portas necessárias:
EXPOSE 1433
EXPOSE 5022

#Habilita o Grupo de Disponibilidade
RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
#Comando que restarta o serviço do sqlserver
#RUN systemctl restart mssql-server

#Destroi todos os clusters e starta serviço do Pacemaker:
RUN pcs cluster destroy 
RUN systemctl enable pacemaker

#Criar cluster de 3 nós:
#RUN pcs cluster auth sqlnode1 sqlnode2 sqlnode3 -u hacluster -p PaSSw0rd
#RUN pcs cluster setup --name clustersqlserver sqlnode1 sqlnode2 sqlnode3
#RUN pcs cluster start --all
#RUN pcs cluster enable --all

#Executar processo do SQL Server:
CMD /opt/mssql/bin/sqlservr

#DESATIVADOS
#Cria um volume para persistência de dados (já apresentado no compose):
#VOLUME sqlnode1:/var/opt/mssql/data/sqlNode1

#Executando o bash após a criação do container e acessando o diretório onde ficam a ferramenta sqlcmd:
#ENTRYPOINT /bin/bash
#WORKDIR cd /opt/mssql-tools/bin/sqlcmd

#Set permissions (if you are using docker with windows, you don´t need to do this)
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.pvk
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.cer
