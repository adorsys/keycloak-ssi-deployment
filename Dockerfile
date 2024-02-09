# Stage 1: Clone the GitHub repository
FROM openjdk:17-jdk-slim AS clone

WORKDIR /app

# Use Git to clone the repository
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git

ARG USERNAME
ARG PAT

# Print USERNAME
RUN echo "USERNAME: $USERNAME"

# Check if PAT is set
RUN if [ -z "$PAT" ]; then echo "PAT is not set"; else echo "PAT is set"; fi


RUN git clone https://ArmandMeppa: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@github.com/adorsys/kc-oid4vci-deployment.git /app/kc-oid4vci-deployment && \
    git -C /app/kc-oid4vci-deployment checkout issue-25638

# Stage 2: Build the project
FROM openjdk:17-jdk-slim AS build

WORKDIR /app

COPY --from=clone /app/kc-oid4vci-deployment .

RUN ./mvnw clean install -DskipTests

# Stage 3: Run the application
FROM eclipse-temurin:17.0.9_9-jre

WORKDIR /app

COPY --from=build /app/quarkus/server/target/lib/ /app/

ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin

CMD ["java", "-jar", "quarkus-run.jar", "start-dev"]
