#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

WORK_DIR="${WORK_DIR:-$PWD}"
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# ---------------------------------------------------------------------------
# Clone and build Keycloak Config CLI if needed
# ---------------------------------------------------------------------------
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
    if [[ -n "$TAG" ]]; then
        log "Checking out tag $TAG..."
        git checkout tags/"$TAG" -b "$TAG"
    fi
    log "Building CLI..."
    ./mvnw clean install -DskipTests
fi

# ---------------------------------------------------------------------------
# Run CLI JAR to import realm configuration
# ---------------------------------------------------------------------------
log "Running Keycloak Config CLI..."
java -DCLIENT_SECRET="$CLIENT_SECRET" \
     -DKEYCLOAK_ADMIN_ADDR="$KEYCLOAK_ADMIN_ADDR" \
     -DKEYCLOAK_KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD" \
     -DKC_KEYSTORE_PATH="$KC_KEYSTORE_PATH" \
     -DKEYCLOAK_REALM="$KEYCLOAK_REALM" \
     -DISSUER_BACKEND_URL="$ISSUER_BACKEND_URL" \
     -DISSUER_FRONTEND_URL="$ISSUER_FRONTEND_URL" \
     -DISSUER_DID="$ISSUER_DID" \
     -DSAML_ENTITYID="$ISSUER_DID" \
     -DTEST_CLIENT_URL="$TEST_CLIENT_URL" \
     -jar "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" \
     -Dimport-realm=true \
     --import.var-substitution.enabled=true \
     --keycloak.url="$KEYCLOAK_ADMIN_ADDR" \
     --keycloak.user="$KC_BOOTSTRAP_ADMIN_USERNAME" \
     --keycloak.password="$KC_BOOTSTRAP_ADMIN_PASSWORD" \
     --keycloak.ssl-verify=false \
     --logging.level.root=info \
     --import.files.locations="$KC_REALM_FILE"

log "Realm configuration imported successfully."

# ---------------------------------------------------------------------------
# Update SD-JWT authenticator configuration
# ---------------------------------------------------------------------------
source "$WORK_DIR/src/utils/update_sdjwt_vct.sh"
