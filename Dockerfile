# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM eclipse-temurin:21-jdk-jammy AS builder

# Set working directory
ENV WORK_DIR=/app
WORKDIR $WORK_DIR


# Install required dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends git apt-utils curl jq gettext-base && \
    rm -rf /var/lib/apt/lists/*

# Install yq (required for configuration management via helper.sh)
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

# Copy environment file
COPY config.yaml ./

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
ENV JAVA_TMPDIR=/tmp

# Create a non-privileged user
RUN groupadd -r keycloak && useradd -r -g keycloak keycloak


# Copy the built Keycloak target from the build stage
COPY --from=builder /app/target /opt/keycloak/target


# Ensure proper permissions
RUN chown -R keycloak:keycloak /opt/keycloak

# Switch to non-privileged user
USER keycloak

# Expose Keycloak default ports
EXPOSE 8443

# Set entrypoint script
ENTRYPOINT ["/bin/sh", "-c", "cd $KEYCLOAK_INSTALL_DIR && exec bin/kc.sh $START_COMMAND $DATABASE_OPTS --features=oid4vc-vci"]
