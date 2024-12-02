#!/bin/bash

# Source common env variables
. load_env.sh

# Shutdown keycloak if any
# Determine OS platform and shutdown Keycloak if running
OS=$(uname -s)
case "$OS" in
    Linux*|Darwin*)
        keycloak_pid=$(pgrep -f keycloak)
        if [ -n "$keycloak_pid" ]; then
            echo "Keycloak instance found (PID: $keycloak_pid) on $OS. Shutting it down..."
            kill $keycloak_pid
        fi
        ;;
    *)
        echo "This script supports only Linux or macOS."
        ;;
esac

# Download, unpack, and prepare Keycloak for start-up.
./setup-kc-oid4vci.sh

# Start database container
if [ -z "${KC_DB_OPTS}" ]; then
    echo "Starting database container..."
    docker-compose up -d db || { echo 'Could not start database container' ; exit 1; }
    KC_DB_OPTS="--db postgres --db-url-port $KC_DB_EXPOSED_PORT --db-url-database $KC_DB_NAME --db-username $KC_DB_USERNAME --db-password $KC_DB_PASSWORD"
fi

# Start keycloak with OID4VCI feature
####
# Use org.keycloak.quarkus._private.IDELauncher if you want to debug through keycloak sources
export KC_BOOTSTRAP_ADMIN_USERNAME KC_BOOTSTRAP_ADMIN_PASSWORD \
&& cd $KC_INSTALL_DIR \
&& bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci &
