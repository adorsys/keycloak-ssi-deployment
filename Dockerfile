# Use a base image with Java 17 and Maven installed
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set the working directory
WORKDIR /app

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Copy necessary files for building and starting keycloak
COPY generate-kc-certs.sh .env setup-kc-oid4vci.sh load_env.sh cert-config.txt kc_keystore.pkcs12 ./

# Download, unpack, and prepare Keycloak
RUN ./setup-kc-oid4vci.sh

# Base image for the runtime stage
FROM openjdk:17-jdk-slim

# Set the working directory
WORKDIR /opt/keycloak

# Copy the built Keycloak deployment from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the environment variable file from the build stage
COPY --from=builder /app/.env /opt/keycloak/

# Copy the custom entrypoint script to the container and make it executable
COPY entrypoint.sh /opt/keycloak/entrypoint.sh
RUN chmod +x /opt/keycloak/entrypoint.sh

# Set the entry point
ENTRYPOINT ["sh", "/opt/keycloak/entrypoint.sh"]
