# Build Stage
FROM openjdk:17-jdk-slim AS builder

WORKDIR /app

# Use Git to clone the repository
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git

# Clone the Keycloak repository
RUN git clone https://github.com/adorsys/kc-oid4vci-deployment.git

# Move the cloned repository to the working directory
RUN mv kc-oid4vci-deployment/* /app

RUN ./mvnw clean install -DskipTests


# Runtime Stage
FROM eclipse-temurin:17.0.9_9-jre

WORKDIR /app

COPY --from=builder /app/quarkus/server/target/lib/ /app/

ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin

CMD ["java", "-jar", "quarkus-run.jar", "start-dev"]