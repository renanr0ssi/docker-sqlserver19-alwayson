﻿FROM mcr.microsoft.com/mssql/server:2019-CU3-ubuntu-16.04
EXPOSE 1433
EXPOSE 5022

LABEL  "MAINTAINER" "Renan Rossi"
LABEL "Project" "SQL Server 2019 AlwaysOn"


ENV ACCEPT_EULA=Y
ENV SA_PASSWORD="PaSSw0rd"
ENV MSSQL_PID=Developer

# Certificate previously generated (see Readme.md)
ENV CERTFILE "certificate/dbm_certificate.cer"
ENV CERTFILE_PWD "certificate/dbm_certificate.pvk"


RUN mkdir /usr/certificate
WORKDIR /usr/
COPY ${CERTFILE} ./certificate
COPY ${CERTFILE_PWD} ./certificate

# Set permissions (if you are using docker with windows, you don´t need to do this)
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.pvk
#RUN chown mssql:mssql /usr/certificate/dbm_certificate.cer

# Enable availability groups
#
RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1

# Run SQL Server process.
CMD /opt/mssql/bin/sqlservr  
