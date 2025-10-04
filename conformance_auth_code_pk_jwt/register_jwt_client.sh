#!/bin/bash

# Register jwt client in Keycloak
# This script creates/updates the openid4vc-rest-api-jwt client

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source load_env.sh from the parent directory
source "$SCRIPT_DIR/../load_env.sh"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

exit_with_error() {
    log_message "❌ ERROR: $1"
    exit 1
}

log_message "Waiting for Keycloak at ${KEYCLOAK_ADMIN_ADDR}..."
until curl -s -k "${KEYCLOAK_ADMIN_ADDR}/health" > /dev/null; do
    sleep 5
done
log_message "Keycloak is running."

# Configure kcadm.sh truststore
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE" || exit_with_error "Failed to configure kcadm.sh truststore"

# Configure admin credentials if not already set
if ! $KC_INSTALL_DIR/bin/kcadm.sh get realms --server "$KEYCLOAK_ADMIN_ADDR" --realm master > /dev/null 2>&1; then
    log_message "Configuring Keycloak admin credentials..."
    $KC_INSTALL_DIR/bin/kcadm.sh config credentials --server "$KEYCLOAK_ADMIN_ADDR" --realm master --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" || exit_with_error "Failed to configure Keycloak admin credentials"
else
    log_message "Admin credentials already configured."
fi

log_message "Checking if JWT client 'openid4vc-rest-api-jwt' already exists..."
CLIENT_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -r "$KEYCLOAK_REALM" --fields id,clientId | jq -r '.[] | select(.clientId=="openid4vc-rest-api-jwt") | .id')

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" == "null" ]; then
    log_message "Creating new JWT client 'openid4vc-rest-api-jwt'..."
    cat "$SCRIPT_DIR/openid4vc-rest-api-jwt.json" | $KC_INSTALL_DIR/bin/kcadm.sh create clients -r "$KEYCLOAK_REALM" -o -f - || exit_with_error "Failed to create JWT client"
    CLIENT_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -r "$KEYCLOAK_REALM" --fields id,clientId | jq -r '.[] | select(.clientId=="openid4vc-rest-api-jwt") | .id')
    log_message "JWT client created successfully."
else
    log_message "JWT client 'openid4vc-rest-api-jwt' already exists. Updating..."
    cat "$SCRIPT_DIR/openid4vc-rest-api-jwt.json" | $KC_INSTALL_DIR/bin/kcadm.sh update clients/$CLIENT_ID -r "$KEYCLOAK_REALM" -o -f - || exit_with_error "Failed to update JWT client"
    log_message "JWT client updated successfully."
fi

log_message "JWT client ID: $CLIENT_ID"

log_message "=== JWT Client Configuration for Conformance Testing ==="
log_message "Client ID: openid4vc-rest-api-jwt"
log_message "Authentication Type: Private Key JWT (client-jwt)"
log_message "Signing Algorithm: ES256"
log_message "Key ID: key-1"
log_message ""

echo ""
log_message ""

log_message "=== Conformance Test Configuration ==="
log_message "For the conformance test, configure:"
log_message "1. Client ID: openid4vc-rest-api-jwt"
log_message "2. Authentication Type: private_key_jwt"
log_message "3. Signing Algorithm: ES256"
log_message "4. Redirect URI: https://demo.certification.openid.net/test/a/keycloak-oid4vci-test/callback"
log_message ""

log_message "JWT client setup completed successfully!"
