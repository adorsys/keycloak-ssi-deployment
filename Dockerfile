# Stage 1: Clone the GitHub repository
FROM node:18-alpine AS clone

WORKDIR /app

ARG GIT_URL=https://ArmandMeppa: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@github.com/adorsys/kc-oid4vci-deployment.git
ARG GIT_BRANCH=issue-25638  # Optional branch to clone, defaults to main

RUN mkdir -p /app
RUN git clone --depth 1 "$GIT_URL" "$GIT_BRANCH" /app

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
