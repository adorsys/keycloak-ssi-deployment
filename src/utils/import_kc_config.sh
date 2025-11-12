#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# WORK_DIR is set by the CLI
TARGET_DIR="${PROJECT_TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# =============================================================================
# Hardcoded Configuration Variables
# These values are project-specific and unlikely to change across environments
# =============================================================================
KC_CLI_PROJECT_DIR="$TARGET_DIR/keycloak-config-cli"
KC_CLI_JAR_FILE="keycloak-config-cli.jar"
REPO_URL="https://github.com/adorsys/keycloak-config-cli.git"

# -----------------------------------------------------------------------------
# Determine keystore path dynamically
# -----------------------------------------------------------------------------
if [[ "$URLS_ADMIN_ADDR" == *"localhost"* || "$URLS_ADMIN_ADDR" == *"127.0.0.1"* ]]; then
    CLI_KEYSTORE_PATH="$TARGET_DIR/kc_keystore.pkcs12"
    log "Detected local Keycloak instance. Using keystore path: $CLI_KEYSTORE_PATH"
else
    CLI_KEYSTORE_PATH="/opt/keycloak/target/kc_keystore.pkcs12"
    log "Detected live Keycloak instance. Using keystore path: $CLI_KEYSTORE_PATH"
fi

if [[ ! -f "$CLI_KEYSTORE_PATH" ]]; then
    error "Keystore not found at $CLI_KEYSTORE_PATH."
fi


# =============================================================================
# Clone and build Keycloak Config CLI if needed
# =============================================================================
if [[ -f "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" ]]; then
    log "Keycloak Config CLI JAR exists. Skipping build."
else
    if [[ -d "$KC_CLI_PROJECT_DIR" ]]; then
        log "Removing existing CLI project folder $KC_CLI_PROJECT_DIR..."
        rm -rf "$KC_CLI_PROJECT_DIR"
    fi
    log "Cloning repository $REPO_URL..."
    git clone "$REPO_URL" "$KC_CLI_PROJECT_DIR"
    cd "$KC_CLI_PROJECT_DIR" || error "Cannot cd to CLI project dir"
    if [[ -n "$CLI_TAG" ]]; then
        log "Checking out tag $CLI_TAG..."
        git checkout tags/"$CLI_TAG" -b "$CLI_TAG"
    fi
    log "Building CLI..."
    ./mvnw clean install -DskipTests
fi

# ---------------------------------------------------------------------------
# Run CLI JAR to import realm configuration
# ---------------------------------------------------------------------------
log "Running Keycloak Config CLI..."
cd "$WORK_DIR" && java -DCLIENT_SECRET="$CLIENTS_SECRET" \
     -DURLS_ADMIN_ADDR="$URLS_ADMIN_ADDR" \
     -DKEYSTORE_PASSWORD="$KEYSTORE_PASSWORD" \
     -DCLI_KEYSTORE_PATH="$CLI_KEYSTORE_PATH" \
     -DKEYCLOAK_REALM="$KEYCLOAK_REALM" \
     -DISSUER_DID="$URLS_ISSUER_DID" \
     -DSAML_ENTITYID="$URLS_ISSUER_DID" \
     -jar "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" \
     -Dimport-realm=true \
     --import.var-substitution.enabled=true \
     --keycloak.url="$URLS_ADMIN_ADDR" \
     --keycloak.user="$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" \
     --keycloak.password="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD" \
     --keycloak.ssl-verify=false \
     --logging.level.root=info \
     --import.files.locations="$CLI_REALM_FILE"

log "Realm configuration imported successfully."

# ---------------------------------------------------------------------------
# Update SD-JWT authenticator configuration
# ---------------------------------------------------------------------------
source "$WORK_DIR/src/utils/update_sdjwt_vct.sh"
