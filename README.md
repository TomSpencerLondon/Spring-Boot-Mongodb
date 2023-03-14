# Docker for Java Developers

### Dockerfiles
- Mongodb dockerfile:
https://github.com/docker-library/mongo/blob/master/6.0/Dockerfile
- recipe of how to build a docker image

Ask for specific ubuntu image:
```dockerfile
FROM ubuntu:jammy
```
Add user to database:
```dockerfile
RUN set -eux; \
	groupadd --gid 999 --system mongodb; \
	useradd --uid 999 --system --gid mongodb --home-dir /data/db mongodb; \
	mkdir -p /data/db /data/configdb; \
	chown -R mongodb:mongodb /data/db /data/configdb
```

Create image layers:

```dockerfile


RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		wget \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
	wget -O /js-yaml.js "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/dist/js-yaml.js"; \
# TODO some sort of download verification here
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# smoke test
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

RUN mkdir /docker-entrypoint-initdb.d

RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	set -- '39BD841E4BE5FB195A65400E6A26B1AE64C3C388'; \
	for key; do \
		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	done; \
	mkdir -p /etc/apt/keyrings; \
	gpg --batch --export "$@" > /etc/apt/keyrings/mongodb.gpg; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"

```

Ubuntu base image is extended by the mongodb image.

### Assign storage on the host
Tell mongo instance to map to specific directory on host machine:

Create a data directory on a suitable volume on your host system, e.g. /my/own/datadir.

Start your mongo container like this:
```bash
$ docker run --name some-mongo -v /my/own/datadir:/data/db -d mongo
```
Persist data:
```bash
docker run -p 27017:27017 -v /home/tom/dockerdata/mongo:/data/db -d mongo
```
check logs with:
```bash
docker logs -f <container name>
```
Run rabbitmq exposing several ports:
```bash
docker run -d --hostname tom-rabbit --name some-rabbit -p 8081:15672 -p 5671:5671 -p 5672:5672 rabbitmq:3-management
```

Create mysql database with volume, port mapping and root password:
```bash
docker run --name guru-mysql -p 3306:3306 -v /home/tom/mysql/data:/etc/mysql/conf.d -e MYSQL_ROOT_PASSWORD=password -d mysql:8.0.32
```
Also without password:
```bash
docker run --name guru-mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -v /home/tom/mysql/data:/etc/mysql/conf.d
mysql
```

Shell into a running docker container:
```bash
docker exec -it <container name> bash
```

### Docker house Keeping
- with development use docker can leave behind a lot of files
- These files will grow and consume a lot of disk space
- This is less of an issue on productoin systems where containers aren't being built
and restarted all the time
- There are 3 key areas of house keeping:
  - continers
  - images
  - volumes

#### Cleaning up Containers
- Kill all running docker containers
  - docker kill $(docker ps -q)
- Delete all stopped docker containers
  - docker rm $(docker ps -a -q)

### Cleaning up images
- Remove a docker image
  - docker rmi <image name>
- Delete untagged (dangling) images
  - docker rmi $(docker images -q -f dangling=true)
- Delete all images
  - docker rmi $(docker images -q)

#### Cleaning up volumes
- Once a volume is no longer associated with a container, it is considered 'dangling'
- Remove all dangling volumes
  - docker volume rm $(docker volume ls -f dangling=true -q)
- NOTE: Does not remove files from host system in shared volumes

### Set up network so that Spring container can access mongodb container:
```bash
docker network create mongo_network

docker run -p 27071:27017 --name mongodb --network mongo_network -d mongo

docker build -t springguru .

docker run -p 8081:8080 --network mongo_network springguru
```
You should also refer to the name of the mongo docker container in the Spring application.properties:
```properties
spring.data.mongodb.host=mongodb
```