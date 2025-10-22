#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

WORK_DIR="${WORK_DIR:-$PWD}"
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/load_env.sh"

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

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
# Extract public key (DER) and compute base64url
# ---------------------------------------------------------------------------
openssl ec -in "$FRANCIS_KEYSTORE_FILE" -passin pass:"$FRANCIS_KEYSTORE_PASSWORD" -pubout -outform der -out "$TARGET_DIR/francis_pub.der"

hex=$(dd if="$TARGET_DIR/francis_pub.der" bs=1 skip=$(($(wc -c < "$TARGET_DIR/francis_pub.der") - 64)) count=64 2>/dev/null | xxd -p -c 64 | tr -d '\n')
x_hex=${hex:0:64}
y_hex=${hex:64:64}

x_b64=$(echo "$x_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')
y_b64=$(echo "$y_hex" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# Prepare user key proof header
jq --arg x "$x_b64" --arg y "$y_b64" '.jwk.x=$x | .jwk.y=$y' "$WORK_DIR/src/config/user_key_proof_header.json" > "$TARGET_DIR/user_key_proof_header.json"

log "User key proof header generated at $TARGET_DIR/user_key_proof_header.json"
