#!/bin/bash

# We work on following assumptions
export DEV_DIR=~/dev
export TOOLS_DIR=~/tools

# Check and create directories
if [ ! -d "$DEV_DIR" ]; then
    echo "Directory $DEV_DIR does not exist, creating..."
    mkdir -p "$DEV_DIR"
    echo "Directory $DEV_DIR created."
else
    echo "Directory $DEV_DIR already exists."
fi

if [ ! -d "$TOOLS_DIR" ]; then
    echo "Directory $TOOLS_DIR does not exist, creating..."
    mkdir -p "$TOOLS_DIR"
    echo "Directory $TOOLS_DIR created."
else
    echo "Directory $TOOLS_DIR already exists."
fi

# change to you DEV_DIR and checkout keycloak
# checkout keycloak
cd $DEV_DIR && git clone --depth 1 https://github.com/keycloak/keycloak.git

# change into keycloak directory
cd $DEV_DIR/keycloak && $DEV_DIR/keycloak/mvnw clean install -DskipTests

# Change to the tools directory
cd $TOOLS_DIR && tar xzf $DEV_DIR/keycloak/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz

# Strart keycloak with OID4VCI feature
# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin
####
# Use org.keycloak.quarkus._private.IDELauncher if you want to debug through keycloak sources
####
cd $TOOLS_DIR/keycloak-999.0.0-SNAPSHOT && bin/kc.sh start-dev --features=oid4vc-vci