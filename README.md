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
CREATE AVAILABILITY GROUP [AG1]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
    N'sqlnode1'
        WITH (
        ENDPOINT_URL = N'tcp://sqlnode1:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            ),
    N'sqlnode2'
        WITH (
        ENDPOINT_URL = N'tcp://sqlnode2:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            ),
    N'sqlnode3'
        WITH (
        ENDPOINT_URL = N'tcp://sqlnode3:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            )
```

_OBS: Aconselho utilizar o Visual Studio Code para se conectar nas bases e rodar os scripts pela interface gráfica.
_OBS: Você pdoerá adicionar mais nós (max de 9) utilizando o comando mais abaixo neste documento [add manually more nodes](###Add_extra_nodes_to_the_availability_group).

5. Conectar as instâncias dos demais nós e executar o script abaixo para linká-los ao Availability Group criado no passo anterior: 

```sql
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE)
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE
GO
```

6. Por fim, crie as bases que afrão parte do grupo de disponibilidade e execute o comando abaixo (trocar "SuaBase" pelo nome da base de dados que tiver sido criada por você):

```sql
ALTER AVAILABILITY GROUP [ag1] ADD DATABASE SuaBase
GO
```

_OBS: Esta base deverá ser criada no nó primário e deverá ter um backup full. 



### Adicionar nós extras no grupo de disponibilidade:

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


## Como criar uma imagem do zero:

1. Primeiramente, será necessário fazer a criação dos certificados que usaremos para fazer a comunicação entre os bancos. Para isso, será necessário se conectar em alguma instancia de banco do Sql Server 2017 e executar o comando abaixo (pode ser realmente qualquer uam instância, podendo ser ate mesmo um docker rodando a imagem limpa do SQL). 

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
TO FILE = 'd:\borrame\dbm_certificate.cer'
WITH PRIVATE KEY (
        FILE = 'd:\borrame\dbm_certificate.pvk',
        ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
    );
GO
```

_This will be used to create a sql login maped to the certificate and replicated to the secondary nodes, required to create the AG_

2. Build the image

```cmd
docker build -t sql2017_alwayson_node .
```

3. Run the container

```cmd
docker run -p 14333:1433 -it sql2017_alwayson_node
```

4. Connect to the 127.0.0.1,14333 and create the following login with certificate to be able to create the AO without cluster

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

5. Stop the docker container

6. Search for the _CONTAINER ID_ that we want to create as a new image

```cmd
docker container list -a
```

7. Commit the container as a new image

```cmd
docker commit 17fed7500df3 sql2017_alwayson_node 
```

8. Search for the _IMAGE ID_ of the new image created in the previous step

```cmd
docker image list
```

9. Put a tag to the image

```cmd
docker tag 530873517958 enriquecatala/sql2017_alwayson_node:latest
```

10. Push to your repository

```cmd
docker push enriquecatala/sql2017_alwayson_node
```


### References

https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-cross-platform?view=sql-server-2017
