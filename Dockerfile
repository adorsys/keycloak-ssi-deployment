# Use a base image with Java 17 and Maven installed
FROM maven:3.8.4-openjdk-17-slim AS builder

# Install Git, apt-utils and other dependencies
RUN apt-get update && apt-get install -y git apt-utils

# Configure Git for large HTTP requests
RUN git config --global http.postBuffer 524288000

# Clone the repository
RUN git clone --depth 1 https://github.com/keycloak/keycloak.git /tmp/keycloak
WORKDIR /tmp/keycloak

# Fetch and checkout the pull request branch
RUN git fetch origin pull/27931/head:pr/wistefan/27931 && \
    git checkout pr/wistefan/27931

# Build Keycloak without running tests
RUN mvn clean install -DskipTests

# Unpack the distribution
RUN tar xzf ./quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz -C /opt
WORKDIR /opt/keycloak-999.0.0-SNAPSHOT



# Environment variables
ENV KEYCLOAK_ADMIN=admin
ENV KEYCLOAK_ADMIN_PASSWORD=admin
ENV KC_HOSTNAME_STRICT=false

# Build Keycloak with the oid4vc-vci feature
RUN bin/kc.sh build --features="oid4vc-vci"

# Entry point
ENTRYPOINT ["bin/kc.sh", "start-dev", "--features=oid4vc-vci"]