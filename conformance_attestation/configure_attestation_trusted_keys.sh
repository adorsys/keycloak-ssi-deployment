#!/bin/bash

# Script to configure trusted keys for attestation proof validation in Keycloak OID4VCI
# 
# Usage:
#   ./configure_attestation_trusted_keys.sh <jwks_file.json>
#
# Example:
#   ./configure_attestation_trusted_keys.sh attestation_trusted_keys.json

# Capture the original JWKS file path and resolve it relative to CWD if exist
JWKS_FILE_INPUT="$1"
JWKS_FILE_RESOLVED=""

if [ -n "$JWKS_FILE_INPUT" ]; then
    if [[ "$JWKS_FILE_INPUT" == /* ]]; then
        JWKS_FILE_RESOLVED="$JWKS_FILE_INPUT"
    elif [ -f "$JWKS_FILE_INPUT" ]; then
        JWKS_FILE_RESOLVED="$(cd "$(dirname "$JWKS_FILE_INPUT")" && pwd)/$(basename "$JWKS_FILE_INPUT")"
    fi
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Source load_env.sh from the parent directory, handling .env file location
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Temporarily change to project root to source .env
    cd "$PROJECT_ROOT"
    source "$PROJECT_ROOT/load_env.sh" 2>/dev/null || {
        # If load_env.sh fails, try to source .env directly
        if [ -f "$PROJECT_ROOT/.env" ]; then
            set -a
            source "$PROJECT_ROOT/.env"
            set +a
        fi
    }
    cd "$SCRIPT_DIR"
else
    echo "Warning: .env file not found at $PROJECT_ROOT/.env"
    echo "Some environment variables may not be set."
fi

# Function to log messages
log_message() {
    local message=$1
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Function to exit with error message
exit_with_error() {
    local message=$1
    log_message "ERROR: $message"
    exit 1
}

log_message "=== Configure Attestation Trusted Keys ==="

# Check if jq is available
if ! command -v jq &> /dev/null; then
    exit_with_error "jq is required but not installed. Please install jq first."
fi

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "  $0 <jwks_file.json>"
    echo ""
    echo "Example:"
    echo "  $0 attestation_trusted_keys.json"
    exit 1
fi

# Get JWKS file path
JWKS_FILE="$JWKS_FILE_RESOLVED"

# If not resolved early, try relative to script dir
if [ -z "$JWKS_FILE" ] && [ -n "$JWKS_FILE_INPUT" ]; then
    if [ -f "$SCRIPT_DIR/$JWKS_FILE_INPUT" ]; then
        JWKS_FILE="$SCRIPT_DIR/$JWKS_FILE_INPUT"
    else
        JWKS_FILE="$JWKS_FILE_INPUT" # Fallback for error message
    fi
fi

if [ ! -f "$JWKS_FILE" ]; then
    exit_with_error "JWKS file not found: $JWKS_FILE"
fi

log_message "Reading trusted keys from file: $JWKS_FILE"

# Extract public keys (remove 'd' parameter if present) and convert to array
TRUSTED_KEYS_JSON=$(jq -c '.keys[] | del(.d) | select(.kid != null)' "$JWKS_FILE" | jq -s '.')

if [ -z "$TRUSTED_KEYS_JSON" ] || [ "$TRUSTED_KEYS_JSON" = "[]" ]; then
    exit_with_error "No valid keys found in JWKS file. Ensure keys have 'kid' field."
fi

# Display the trusted keys that will be configured
log_message "Trusted keys to configure:"
echo "$TRUSTED_KEYS_JSON" | jq .

# Check required environment variables
if [ -z "$KC_INSTALL_DIR" ]; then
    exit_with_error "KC_INSTALL_DIR environment variable is not set. Please check your .env file."
fi

if [ ! -f "$KC_INSTALL_DIR/bin/kcadm.sh" ]; then
    exit_with_error "kcadm.sh not found at $KC_INSTALL_DIR/bin/kcadm.sh"
fi

if [ -z "$KEYCLOAK_ADMIN_ADDR" ]; then
    exit_with_error "KEYCLOAK_ADMIN_ADDR environment variable is not set. Please check your .env file."
fi

if [ -z "$KEYCLOAK_REALM" ]; then
    exit_with_error "KEYCLOAK_REALM environment variable is not set. Please check your .env file."
fi

if [ -z "$KC_BOOTSTRAP_ADMIN_USERNAME" ] || [ -z "$KC_BOOTSTRAP_ADMIN_PASSWORD" ]; then
    exit_with_error "KC_BOOTSTRAP_ADMIN_USERNAME and KC_BOOTSTRAP_ADMIN_PASSWORD must be set. Please check your .env file."
fi

# Get admin token
log_message "Obtaining admin token..."
if [ -n "$KC_TRUST_STORE" ] && [ -n "$KC_TRUST_STORE_PASS" ]; then
    $KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE" 2>/dev/null || true
fi

$KC_INSTALL_DIR/bin/kcadm.sh config credentials \
    --server "$KEYCLOAK_ADMIN_ADDR" \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" || \
    exit_with_error "Failed to authenticate with Keycloak admin"

# Check if realm exists, create if it doesn't
log_message "Checking if realm '$KEYCLOAK_REALM' exists..."
if ! $KC_INSTALL_DIR/bin/kcadm.sh get realms/"$KEYCLOAK_REALM" > /dev/null 2>&1; then
    log_message "Realm '$KEYCLOAK_REALM' does not exist. Creating it..."
    $KC_INSTALL_DIR/bin/kcadm.sh create realms \
        -s realm="$KEYCLOAK_REALM" \
        -s enabled=true || \
        exit_with_error "Failed to create realm '$KEYCLOAK_REALM'"
    log_message "✅ Realm '$KEYCLOAK_REALM' created successfully"
else
    log_message "Realm '$KEYCLOAK_REALM' already exists"
fi

# Update realm attribute
log_message "Updating realm attribute: oid4vc.attestation.trusted_keys"
log_message "Realm: $KEYCLOAK_REALM"

# Convert the JSON array to a compact string for the realm attribute
# Realm attributes are stored as strings, so we need to pass the JSON as a string
TRUSTED_KEYS_STRING=$(echo "$TRUSTED_KEYS_JSON" | jq -c .)

# Create JSON payload for realm update
REALM_UPDATE_JSON=$(jq -n \
    --arg trusted_keys_str "$TRUSTED_KEYS_STRING" \
    '{
        "attributes": {
            "oid4vc.attestation.trusted_keys": $trusted_keys_str
        }
    }')

log_message "Realm update payload:"
echo "$REALM_UPDATE_JSON" | jq .

# Use kcadm.sh to update the realm by piping JSON via stdin
echo "$REALM_UPDATE_JSON" | $KC_INSTALL_DIR/bin/kcadm.sh update realms/"$KEYCLOAK_REALM" -f - || \
    exit_with_error "Failed to update realm attribute"

log_message "✅ Successfully configured trusted keys for attestation proof validation"
log_message ""
log_message "Summary:"
log_message "- Realm: $KEYCLOAK_REALM"
log_message "- Attribute: oid4vc.attestation.trusted_keys"
log_message "- Number of keys: $(echo "$TRUSTED_KEYS_JSON" | jq 'length')"
log_message ""
log_message "Key IDs configured:"
echo "$TRUSTED_KEYS_JSON" | jq -r '.[].kid' | while read -r kid; do
    log_message "  - $kid"
done
