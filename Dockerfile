FROM docker.io/library/openjdk:27-ea-17-jdk-oracle
EXPOSE 8080
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]