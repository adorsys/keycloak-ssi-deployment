# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM eclipse-temurin:21-jdk-jammy AS builder

# Set working directory
ENV WORK_DIR=/app
WORKDIR $WORK_DIR


# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends git apt-utils curl jq && rm -rf /var/lib/apt/lists/*

# Copy environment file
COPY .env ./

# Copy necessary source scripts
COPY src/deployment ./src/deployment
COPY src/utils ./src/utils

# Run setup to prepare Keycloak OID4VCI environment
RUN chmod +x src/deployment/setup-kc-oid4vci.sh && ./src/deployment/setup-kc-oid4vci.sh

# ==========================================
# Stage 2: Runtime Stage
# ==========================================
FROM eclipse-temurin:21-jdk-jammy

# Set working directory
WORKDIR /opt/keycloak

# Create a non-privileged user
RUN groupadd -r keycloak && useradd -r -g keycloak keycloak

# Copy the built Keycloak target from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the .env file to runtime
COPY --from=builder /app/.env /opt/keycloak/

# Copy entrypoint script and make it executable
COPY entrypoint.sh /opt/keycloak/entrypoint.sh
RUN chmod +x /opt/keycloak/entrypoint.sh && chown -R keycloak:keycloak /opt/keycloak

# Switch to non-privileged user
USER keycloak

# Expose Keycloak default ports
EXPOSE 8443

# Set entrypoint
ENTRYPOINT ["sh", "/opt/keycloak/entrypoint.sh"]
