# Use a base image with Java 17 and Maven installed
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set the working directory
WORKDIR /app

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Copy necessary files for building and starting keycloak
COPY generate-kc-certs.sh .env build-kc-oid4vci.sh load_env.sh cert-config.txt kc_keystore.pkcs12 ./

# Run the Keycloak start-up script
RUN ./build-kc-oid4vci.sh

# Base image for the runtime stage
FROM openjdk:17-jdk-slim

# Set the working directory
WORKDIR /opt/keycloak/

# Copy the built Keycloak deployment from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the environment variable file from the build stage
COPY --from=builder /app/.env /opt/keycloak/

# Set the entry point
ENTRYPOINT ["sh", "-c", "set -a && . /opt/keycloak/.env && set +a && cd $KC_INSTALL_DIR && bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci"]
