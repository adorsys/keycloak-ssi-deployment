# Stage 1: Build the project
FROM openjdk:17-jdk-slim AS build

WORKDIR /app

COPY ./deployment .

RUN ./mvnw clean install -DskipTests

# Stage 2: Run the application
FROM eclipse-temurin:17.0.9_9-jre

WORKDIR /app

COPY --from=build /app/quarkus/server/target/lib/ /app/

ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin \
    HTTPS_ENABLED=false

CMD ["java", "-jar", "quarkus-run.jar", "start-dev"]
