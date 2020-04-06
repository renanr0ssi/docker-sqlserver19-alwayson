# Docker SQL Server 2017 Alwayson

Templates de Docker para criar um grupo de Alta DIsponibilidade (HA) com 03 nós de SQL Server 2019.


## Como criar uma topologia de AlwaysOn com 03 nós usando Docker:

Estes laboratório foi criada em cima de um servidor Linux Ubuntu 18.04 rodando Docker 19.03, portanto partirei do presuporto que seu ambiente estará com esta confguração ou similar compativel. 

1. Faça o clone deste repositório em uma maquina Linux a qual você utilizará para subir os dockers.

2. Acesse a raiz do diretório onde clonou este repositório e envie o comando abaixo.
```cmd
docker-compose build
```

_OBS: Este comando irá construir a infraestrutura seguindo os parametros especificados no arquivo de docker-compose._
_OBS: Este arquivo de docker-compose foi criado baseado na imagem gerada pelo 2017.Dockerfile._

3. Execute o comando abaixo para rodar a infra construida no comando anterior:

```cmd
docker-compose up
```
Agora você possui 3 nós na mesma rede preparados para fazerem parte de um novo Availability Group. 

4. Conecte no nó 1 (sqlnode1) e execute o script abaixo para realizar a criação do grupo de disponibilidade:

```sql
CREATE AVAILABILITY GROUP [ag1]
     WITH (DB_FAILOVER = ON, CLUSTER_TYPE = EXTERNAL)
     FOR REPLICA ON
     N'sqlnode1'
          WITH (
             ENDPOINT_URL = N'tcp://sqlnode1:5022',
             AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
             FAILOVER_MODE = EXTERNAL,
             SEEDING_MODE = AUTOMATIC
             ),
     N'sqlnode2'
          WITH ( 
             ENDPOINT_URL = N'tcp://sqlnode2:5022',
             AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
             FAILOVER_MODE = EXTERNAL,
             SEEDING_MODE = AUTOMATIC
             ),
         N'sqlnode3'
         WITH( 
            ENDPOINT_URL = N'tcp://sqlnode3:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            FAILOVER_MODE = EXTERNAL,
            SEEDING_MODE = AUTOMATIC
            );
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
```

_OBS: Aconselho utilizar o Visual Studio Code para se conectar nas bases e rodar os scripts pela interface gráfica._
_OBS: Você pdoerá adicionar mais nós (max de 9) utilizando o comando mais abaixo neste documento._

5. Conectar as instâncias dos demais nós e executar o script abaixo para linká-los ao Availability Group criado no passo anterior: 

```sql
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE)
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE
GO
```

6. Por fim, crie as bases que farão parte do grupo de disponibilidade, sete o BKP e ative-a no Grupo de Disponibilidade. O comando abaixo trata estes pontos (trocar "SuaBase01" pelo nome da base de dados que tiver sido criada por você). 

```sql
CREATE DATABASE [SuaBase01];
ALTER DATABASE [SuaBase01] SET RECOVERY FULL;
BACKUP DATABASE [SuaBase01] 
   TO DISK = N'/var/opt/mssql/data/SuaBase01.bak';

ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [db1];
```

_OBS: Esta base deverá ser criada no nó primário e deverá ter um backup full._

7. Execute o comando abaixo nos nós secundários para validar se a replicação foi realizada com sucesso entre os nós:
```sql
SELECT * FROM sys.databases WHERE name = 'SuaBase01';
GO
SELECT DB_NAME(database_id) AS 'database', synchronization_state_desc FROM sys.dm_hadr_database_replica_states;
```

_____________________________________________________________________________________________________________________

## Adicionar nós extras no grupo de disponibilidade:

1. Execute o script abaixo no nó o qual você queira adicionar.
2. Copie a saida desse script e execute ele novamente no nó primário.

```sql
DECLARE @servername AS sysname
SELECT @servername=CAST( SERVERPROPERTY('ServerName') AS sysname)

DECLARE @cmd AS VARCHAR(MAX)

SET @cmd ='
ALTER AVAILABILITY GROUP [AG1]    
    ADD REPLICA ON
        N''<SQLInstanceName>''
     WITH (
        ENDPOINT_URL = N''tcp://<SQLInstanceName>:5022'',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
         )
';

DECLARE @create_ag AS VARCHAR(MAX)
SELECT @create_ag = REPLACE(@cmd,'<SQLInstanceName>',@servername)

-- NOW, go to primary replica and execute the output script generated
--
PRINT @create_ag
```


_____________________________________________________________________________________________________________________

## Como criar uma imagem do zero utilizando este repositório:

01. Primeiramente, será necessário fazer a criação dos certificados que usaremos para fazer a comunicação entre os bancos. Para isso, será necessário se conectar em alguma instancia de banco do Sql Server 2017 e executar o comando abaixo (pode ser realmente qualquer uam instância, podendo ser ate mesmo um docker rodando a imagem limpa do SQL). 
_OBS: Ajuste o diretório ao qual você quer alocar o seu certificado:_

```sql
USE master
GO
CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
go
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
TO FILE = '/home/usuario/repositorio-git/certificate/dbm_certificate.cer'
WITH PRIVATE KEY (
        FILE = '/home/usuario/repositorio-git/certificate/dbm_certificate.pvk',
        ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
    );
GO
```


02. Buildar a imagem utilizando o 2017.dockerfile:

```cmd
docker build -t docker-sqlserver2017-pacemaker -f 2017.Dockerfile .
```

03. Rodar o container com a imagem buildada:

```cmd
docker run -p 14333:1433 -it docker-sqlserver2017-pacemaker
```

04. Conectar na instancia desse banco que acabamos de subir e executar os 2 scripts abaixo para que seja:
* habilitada a sessão de eventos 
* criado o login de acesso utilizando o certificado recém-criado
* criado os endpoints de comunicação

_OBS: pode-se conectar utilizando o Visual Studio Code (pegar o IP do container utilizando o comando Docker Inspect ID_DO_CONTAINER) ou atraves do comando: (*docker exec -it sqlnode1 "bash"*) e dentro dele rodar o (/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P PaSSw0rd)_

```sql
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
```

```sql
CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create master key encryption required to securely store the certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
GO
-- import certificate with authorization to dbm_user
CREATE CERTIFICATE dbm_certificate   
    AUTHORIZATION dbm_user
    FROM FILE = '/usr/certificate/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/usr/certificate/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = 'Pa$$w0rd'
)
GO
-- Create the endpoint
--
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login]
GO
```

05. Rodar o comando abaixo para acessar o container via terminal:
```cmd
docker init -it NOME_DO_CONTAINER "bash"
```

06. Realizar a troca da senha do PaceMaker utilizando o comando abaixo:
```cmd
passwd hacluster
```
_OBS: Utilizar a senha: PaSSw0rd_

07. Habilitar e Iniciar o PCSD e o PaceMaker:
```cmd
systemctl enable pcsd
systemctl enable pacemaker
/etc/init.d/pacemaker start
/etc/init.d/pcsd start
```

08. Criar login de SQL para o Pacemaker e salvar suas credenciais:
```sql
USE [master]
GO
CREATE LOGIN hacluster with PASSWORD= N'PaSSw0rd'
ALTER SERVER ROLE [sysadmin] ADD MEMBER hacluster
```

```cmd
echo 'hacluster' >> ~/pacemaker-passwd
echo 'PaSSw0rd' >> ~/pacemaker-passwd
mv ~/pacemaker-passwd /var/opt/mssql/secrets/passwd
chown root:root /var/opt/mssql/secrets/passwd
chmod 400 /var/opt/mssql/secrets/passwd # Only readable by root
```

09. Parar o container:
```cmd
docker stop ID_DO_CONTAINER
```

10. Commitar o container com a nova imagem:
```cmd
docker commit ID_DO_CONTAINER docker-sqlserver2017-pacemaker
```

11. Tagear a imagem a ser criada:
_OBS: o comando (docker images) traz os IDs das imagens._
```cmd
docker tag ID_DA_IMAGEM renanrossi/docker-sqlserver2017-pacemaker
```

12. Realizar login no docker:
```cmd
docker login
```

13. Dar Push para o repostório no Docker Hub:
```cmd
docker push renanrossi/docker-sqlserver2017-pacemaker
```

_____________________________________________________________________________________________________________________
### Referencias:
https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-cross-platform?view=sql-server-2017
https://docs.microsoft.com/pt-br/sql/linux/quickstart-install-connect-docker?view=sql-server-ver15&pivots=cs1-bash
https://docs.microsoft.com/pt-br/sql/linux/sql-server-linux-configure-docker?view=sql-server-ver15

