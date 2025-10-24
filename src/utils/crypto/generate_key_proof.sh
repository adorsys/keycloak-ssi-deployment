#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Generate a key proof for OID4VCI
# -----------------------------------------------------------------------------

WORK_DIR="${WORK_DIR:-$PWD}"
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ -z "${CREDENTIAL_ACCESS_TOKEN:-}" ]]; then
    error "CREDENTIAL_ACCESS_TOKEN is missing."
fi

if [[ -z "${C_NONCE:-}" ]] || [[ "$C_NONCE" == "null" ]]; then
    error "C_NONCE (challenge nonce) is missing. Retrieve it from Keycloak nonce endpoint first."
fi

# ---------------------------------------------------------------------------
# Prepare payload
# ---------------------------------------------------------------------------
iat=$(date +%s)
nonce="$C_NONCE"
aud="${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}"

jq --argjson iat "$iat" --arg nonce "$nonce" --arg aud "$aud" \
   '.iat = $iat | .nonce = $nonce | .aud = $aud' \
   "$WORK_DIR/src/config/user_key_proof_payload.json" \
   > "$TARGET_DIR/user_key_proof_payload.json"

# ---------------------------------------------------------------------------
# Encode header and payload
# ---------------------------------------------------------------------------
KEY_PROOF_HEADER_BASE64URL=$(openssl base64 -in "$WORK_DIR/src/config/user_key_proof_header.json" -A | tr '+/' '-_' | tr -d '=')
KEY_PROOF_PAYLOAD_BASE64URL=$(openssl base64 -in "$TARGET_DIR/user_key_proof_payload.json" -A | tr '+/' '-_' | tr -d '=')

SIGN_INPUT="$KEY_PROOF_HEADER_BASE64URL.$KEY_PROOF_PAYLOAD_BASE64URL"

# ---------------------------------------------------------------------------
# Extract private key
# ---------------------------------------------------------------------------
openssl pkcs12 -in "$FRANCIS_KEYSTORE_FILE" -nocerts -nodes -out "$TARGET_DIR/francis_private_key.pem" -passin pass:"$FRANCIS_KEYSTORE_PASSWORD"

openssl dgst -sha256 -sign "$TARGET_DIR/francis_private_key.pem" -out "$TARGET_DIR/signature.der" <<< "$SIGN_INPUT"

# Extract R and S values and base64url encode
R_HEX=$(openssl asn1parse -inform DER -in "$TARGET_DIR/signature.der" | grep -A 1 'INTEGER' | head -n 1 | awk '{print $7}' | tr -d ':')
S_HEX=$(openssl asn1parse -inform DER -in "$TARGET_DIR/signature.der" | grep -A 1 'INTEGER' | tail -n 1 | awk '{print $7}' | tr -d ':')

KEY_PROOF_SIGN_BASE64URL=$(echo "$R_HEX$S_HEX" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

# ---------------------------------------------------------------------------
# Construct final user key proof
# ---------------------------------------------------------------------------
USER_KEY_PROOF="$KEY_PROOF_HEADER_BASE64URL.$KEY_PROOF_PAYLOAD_BASE64URL.$KEY_PROOF_SIGN_BASE64URL"

log "USER_KEY_PROOF generated:"
echo -e "$USER_KEY_PROOF\n"
