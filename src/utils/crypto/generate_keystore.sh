#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Generate Keycloak keystore with EC and RSA keys
# -----------------------------------------------------------------------------

# WORK_DIR is set by the CLI
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

if [[ -f "$KEYCLOAK_KEYSTORE_FILE" ]]; then
    log "Keystore $KEYCLOAK_KEYSTORE_FILE already exists. Skipping generation."
    exit 0
fi

log "Generating keystore $KEYCLOAK_KEYSTORE_FILE..."

# EC key (ECDSA)
keytool -genkeypair \
    -keyalg EC -keysize 256 -validity 3650 \
    -keystore "$KEYCLOAK_KEYSTORE_FILE" -storepass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -alias "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS" -keypass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -storetype "$KEYCLOAK_KEYSTORE_TYPE" \
    -dname "CN=ECDSA Signing Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangangte, ST=West, C=CM"

# RSA signing key
keytool -genkeypair \
    -keyalg RSA -keysize 3072 -validity 3650 \
    -keystore "$KEYCLOAK_KEYSTORE_FILE" -storepass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -alias "$KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS" -keypass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -storetype "$KEYCLOAK_KEYSTORE_TYPE" \
    -dname "CN=RSA Signing Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangangte, ST=West, C=CM"

# RSA encryption key
keytool -genkeypair \
    -keyalg RSA -keysize 3072 -validity 3650 \
    -keystore "$KEYCLOAK_KEYSTORE_FILE" -storepass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -alias "$KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS" -keypass "$KEYCLOAK_KEYSTORE_PASSWORD" \
    -storetype "$KEYCLOAK_KEYSTORE_TYPE" \
    -dname "CN=RSA Encryption Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangangte, ST=West, C=CM"

log "Keystore generated successfully at $KEYCLOAK_KEYSTORE_FILE."
