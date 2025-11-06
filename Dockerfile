# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set working directory
WORKDIR /app

# Install required dependencies
RUN apt-get update && apt-get install -y git apt-utils curl jq && apt-get clean

# Copy environment file
COPY .env ./

# Copy necessary setup and utility scripts
COPY src/deployment/setup-kc-oid4vci.sh src/utils/crypto/cert-config.txt ./

# Copy additional utility scripts used by setup
COPY src/utils/crypto/generate-kc-certs.sh src/utils/crypto/generate_keystore.sh src/utils/crypto/generate_user_key.sh ./utils/
RUN chmod +x ./utils/*.sh

# Run setup to prepare Keycloak OID4VCI environment
RUN chmod +x setup-kc-oid4vci.sh && ./setup-kc-oid4vci.sh

# ==========================================
# Stage 2: Runtime Stage
# ==========================================
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /opt/keycloak

# Copy the built Keycloak target from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the .env file to runtime
COPY --from=builder /app/.env /opt/keycloak/

# Copy entrypoint script and make it executable
COPY entrypoint.sh /opt/keycloak/entrypoint.sh
RUN chmod +x /opt/keycloak/entrypoint.sh

# Expose Keycloak default ports
EXPOSE 8443

# Set entrypoint
ENTRYPOINT ["sh", "/opt/keycloak/entrypoint.sh"]
