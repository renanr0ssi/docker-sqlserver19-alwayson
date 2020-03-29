#Baixar imagem de SQL Server 2019 com Ubuntu 18.04:
FROM mcr.microsoft.com/mssql/server:2019-CU3-ubuntu-18.04

#Aceite dos termos do SQL Server, seta senha do user SA e utiliza a licença de Dev:
ENV ACCEPT_EULA=Y
ENV SA_PASSWORD="PaSSw0rd"
ENV MSSQL_PID=Developer

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

#Cria um volume para persistência de dados:
VOLUME sqlnode1:/var/opt/mssql/data/sqlNode1

ENTRYPOINT /bin/bash

# Set permissions (if you are using docker with windows, you don´t need to do this)
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.pvk
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.cer

# Enable availability groups
#RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1

# Run SQL Server process.
#CMD /opt/mssql/bin/sqlservr  

#docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=PaSSw0rd" -p 1433:1433 --name sql1 -d mcr.microsoft.com/mssql/server:2019-CU3-ubuntu-18.04
