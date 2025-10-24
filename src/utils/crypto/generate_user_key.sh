#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

WORK_DIR="${WORK_DIR:-$PWD}"
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# ---------------------------------------------------------------------------
# Generate ECDSA Key in keystore if missing
# ---------------------------------------------------------------------------
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
        -dname "CN=Francis Pouatcha, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=CM"
else
    log "Keystore $FRANCIS_KEYSTORE_FILE already exists. Skipping generation."
fi

# ---------------------------------------------------------------------------
# Extract public key and convert to JWK format
# ---------------------------------------------------------------------------
# Extract public key directly from keystore
keytool -export -alias "$FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS" -keystore "$FRANCIS_KEYSTORE_FILE" -storepass "$FRANCIS_KEYSTORE_PASSWORD" -file "$TARGET_DIR/francis_pub.der"

# Convert to PEM and extract coordinates
openssl x509 -inform DER -in "$TARGET_DIR/francis_pub.der" -pubkey -noout > "$TARGET_DIR/francis_pub.pem"

# Extract EC coordinates using a more reliable method
openssl ec -pubin -in "$TARGET_DIR/francis_pub.pem" -text -noout > "$TARGET_DIR/ec_info.txt"

# Extract x and y coordinates from the EC info
x_hex=$(grep -A 1 "pub:" "$TARGET_DIR/ec_info.txt" | tail -n 1 | sed 's/^[[:space:]]*04[[:space:]]*//' | cut -c1-64)
y_hex=$(grep -A 1 "pub:" "$TARGET_DIR/ec_info.txt" | tail -n 1 | sed 's/^[[:space:]]*04[[:space:]]*//' | cut -c65-128)

# Convert to base64url
x_b64=$(echo "$x_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')
y_b64=$(echo "$y_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# Prepare user key proof header
jq --arg x "$x_b64" --arg y "$y_b64" '.jwk.x=$x | .jwk.y=$y' "$WORK_DIR/src/config/user_key_proof_header.json" > "$TARGET_DIR/user_key_proof_header.json"

log "User key proof header generated at $TARGET_DIR/user_key_proof_header.json"
