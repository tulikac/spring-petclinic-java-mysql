FROM maven as builder

COPY src /usr/src/app/src
COPY pom.xml /usr/src/app

RUN mvn -f /usr/src/app/pom.xml clean package

FROM openjdk

COPY --from=builder /usr/src/app/target/spring-petclinic-2.7.3.jar /usr/app/spring-petclinic-2.7.3.jar

ENTRYPOINT ["java", "-jar", "/usr/app/spring-petclinic-2.7.3.jar"]