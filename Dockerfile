# Use a base image with Java 17 and Maven installed
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set the working directory
WORKDIR /app

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Copy the Keycloak deployment scripts
COPY . .

# Run the Keycloak start-up script
RUN ./0.start-kc-oid4vci.sh

# Base image for the runtime stage
FROM openjdk:17-jdk-slim

# Set the working directory
WORKDIR /opt/keycloak/

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Copy the built Keycloak deployment from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the Keycloak configuration scripts and dependencies
COPY --from=builder /app/.env /opt/keycloak/

# Expose the Keycloak port
EXPOSE 8443

# Set the entry point
ENTRYPOINT ["sh", "-c", "set -a && . /opt/keycloak/.env && cd $KC_INSTALL_DIR && bin/kc.sh $KC_START --features=oid4vc-vci & tail -f /dev/null"]