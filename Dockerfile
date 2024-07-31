# Use a base image with Java 17 and Maven installed
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set the working directory
WORKDIR /app

# Copy the Keycloak deployment scripts
COPY . .

# Run the Keycloak start-up script
RUN ./0.start-kc-oid4vci.sh

# Base image for the runtime stage
FROM openjdk:17-jdk-slim

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Copy the built Keycloak deployment from the build stage
COPY --from=builder /app/target /opt/keycloak/

# Copy the Keycloak configuration scripts and dependencies
COPY --from=builder /app/*.sh /opt/keycloak/
COPY --from=builder /app/*.json /opt/keycloak/
COPY --from=builder /app/.env /opt/keycloak/

# Set the working directory
WORKDIR /opt/keycloak/

# Expose the Keycloak port
EXPOSE 8443

# Entry point
ENTRYPOINT ["sh", "-c", "/opt/keycloak/0.start-kc-oid4vci.sh && /opt/keycloak/1.oid4vci_test_deployment.sh \
            && /opt/keycloak/2.configure_user_4_account_client.sh"]