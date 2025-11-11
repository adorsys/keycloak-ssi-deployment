# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM maven:3.8.4-openjdk-17-slim AS builder

# Set working directory
WORKDIR /app

# Install required dependencies
RUN apt-get update && apt-get install -y git apt-utils curl jq gettext && apt-get clean

# Install yq (required for configuration management)
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

# Copy environment file
COPY config.yaml config.override.yaml ./

# Copy necessary setup and utility scripts
RUN mkdir -p src/utils/crypto
COPY src/deployment/setup-kc-oid4vci.sh ./
COPY src/utils/helper.sh src/utils/
COPY src/utils/crypto/cert-config.txt src/utils/crypto/kc_keystore.pkcs12 src/utils/crypto/

# Copy additional utility scripts used by setup
COPY src/utils/crypto/generate-kc-certs.sh src/utils/crypto/generate_keystore.sh src/utils/crypto/generate_user_key.sh src/utils/crypto/
RUN chmod +x src/utils/crypto/*.sh

# Run setup to prepare Keycloak OID4VCI environment
RUN chmod +x setup-kc-oid4vci.sh && \
    export WORK_DIR=/app && \
    ./setup-kc-oid4vci.sh

# ==========================================
# Stage 2: Runtime Stage
# ==========================================
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /opt/keycloak
ENV JAVA_TMPDIR=/tmp

# Copy the built Keycloak target from the build stage
COPY --from=builder /app/target /opt/keycloak/target

# Copy the .env file to runtime
# Configuration files are loaded by the setup script in the builder stage,
# and the resulting Keycloak installation is copied. No need to copy config files to runtime.

# Expose Keycloak default ports
EXPOSE 8443

# Set entrypoint command
CMD ["/opt/keycloak/target/bin/kc.sh", "${START_COMMAND}", "${KC_DB_OPTS}", "--features=oid4vc-vci,oid4vc-vpauth"]
