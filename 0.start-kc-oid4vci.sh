#!/bin/bash

# We work on following assumptions
export DEV_DIR=~/dev
export TOOLS_DIR=~/tools

# change to you DEV_DIR and checkout keycloak
# checkout keycloak
cd $DEV_DIR && git clone https://github.com/keycloak/keycloak.git

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