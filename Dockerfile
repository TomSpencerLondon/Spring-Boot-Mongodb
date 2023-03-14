FROM ubuntu:18.04

RUN apt-get update && \
    apt-get -y install openjdk-8-jdk

COPY  /target/spring-boot-mongodb-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
