#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Generate ECDSA Key and Extract Public Coordinates for JWK
# -----------------------------------------------------------------------------

# WORK_DIR is set by the CLI
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# -----------------------------------------------------------------------------
# Generate ECDSA Key in keystore if missing
# -----------------------------------------------------------------------------
if [[ ! -f "$FRANCIS_KEYSTORE_FILE" ]]; then
    log "Generating ECDSA key in $FRANCIS_KEYSTORE_FILE..."
    keytool -genkeypair \
        -keyalg EC \
        -groupname secp256r1 \
        -keystore "$FRANCIS_KEYSTORE_FILE" \
        -storepass "$FRANCIS_KEYSTORE_PASSWORD" \
        -alias "$FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS" \
        -keypass "$FRANCIS_KEYSTORE_PASSWORD" \
        -storetype "$FRANCIS_KEYSTORE_TYPE" \
        -dname "CN=Francis Pouatcha, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=Cameroon"
else
    log "Keystore $FRANCIS_KEYSTORE_FILE already exists. Skipping generation."
fi

# -----------------------------------------------------------------------------
# Extract public key in DER format
# -----------------------------------------------------------------------------
log "Extracting public key in DER format..."
cat "$FRANCIS_KEYSTORE_FILE" | openssl ec \
    -passin pass:"$FRANCIS_KEYSTORE_PASSWORD" \
    -pubout -outform der \
    -out "$TARGET_DIR/francis_pub.der"

# -----------------------------------------------------------------------------
# Extract X and Y coordinates from DER
# -----------------------------------------------------------------------------
# Get last 64 bytes (public key coordinates for P-256)
hex=$(dd if="$TARGET_DIR/francis_pub.der" bs=1 skip=$(($(wc -c < "$TARGET_DIR/francis_pub.der") - 64)) count=64 2>/dev/null | xxd -p | tr -d '\n')

# Split into X and Y (each 32 bytes / 64 hex chars)
x_hex="${hex:0:64}"
y_hex="${hex:64:64}"

# -----------------------------------------------------------------------------
# Convert hex to Base64URL (no padding)
# -----------------------------------------------------------------------------
x_b64=$(echo "$x_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')
y_b64=$(echo "$y_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

# -----------------------------------------------------------------------------
# Build user key proof header JSON
# -----------------------------------------------------------------------------
cat "$WORK_DIR/src/config/user_key_proof_header.json" | jq --arg x "$x_b64" --arg y "$y_b64" \
    '.jwk.x = $x | .jwk.y = $y' \
    > "$TARGET_DIR/user_key_proof_header.json"

log "User key proof header generated at: $TARGET_DIR/user_key_proof_header.json"
