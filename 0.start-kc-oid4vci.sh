#!/bin/bash

# Source common env variables
. ./common_vars.sh

# Check and create directories
if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR does not exist, creating..."
    mkdir -p "$TARGET_DIR"
    echo "Directory $TARGET_DIR created."
else
    echo "Directory $TARGET_DIR already exists."
fi

if [ ! -d "$TOOLS_DIR" ]; then
    echo "Directory $TOOLS_DIR does not exist, creating..."
    mkdir -p "$TOOLS_DIR"
    echo "Directory $TOOLS_DIR created."
else
    echo "Directory $TOOLS_DIR already exists."
fi

# change to you TARGET_DIR and checkout keycloak
# checkout keycloak
if [ ! -d "$TARGET_DIR/$KC_OID4VCI" ]; then
    echo "Directory $TARGET_DIR/$KC_OID4VCI does not exist, cloning repo..."
    cd $TARGET_DIR && git clone --depth 1 https://github.com/keycloak/keycloak.git $TARGET_DIR/$KC_OID4VCI
    echo "Keycloak cloned into $TARGET_DIR/$KC_OID4VCI."
else
    echo "Directory $TARGET_DIR/$KC_OID4VCI already exists."
fi


# change into keycloak directory & build keycloak
if [ ! -f "$TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz" ]; then
    echo "File $TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz does not exist, building keycloak..."
    cd $TARGET_DIR/$KC_OID4VCI && $TARGET_DIR/$KC_OID4VCI/mvnw clean install -DskipTests || { echo 'Could not build keycloak' ; exit 1; }
    echo "Keycloak installed"
else
    echo "Keycloak already installed, will skip build."
fi

# Shutdown keycloak if any
keycloak_pid=$(ps aux | grep -i '[k]eycloak' | awk '{print $2}')
if [ -n "$keycloak_pid" ]; then
    echo "A Keycloak instance is already running (PID: $keycloak_pid). Shutting it down..."
    kill $keycloak_pid 
fi

# Change to the tools directory and unpack keycloak
if [ -d "$KC_INSTALL_DIR" ]; then
    echo "Directory KC_INSTALL_DIR exists,  remove it"
    cd $TOOLS_DIR && rm -rf $KC_INSTALL_DIR || { echo 'Could not remove keycloak install' ; exit 1; }
fi

echo "unpacking keycloak ..."
cd $TOOLS_DIR && tar xzf $TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz || { echo 'Could not unpack keycloak' ; exit 1; }

# Strart keycloak with OID4VCI feature
####
# Use org.keycloak.quarkus._private.IDELauncher if you want to debug through keycloak sources
export KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN && export KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD && cd $KC_INSTALL_DIR && bin/kc.sh start-dev --features=oid4vc-vci