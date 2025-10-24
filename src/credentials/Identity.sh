#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ===============================
# Load Environment
# ===============================
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# ===============================
# Credential Type
# ===============================
CREDENTIAL_TYPE="${1:-IdentityCredential}"  # default to IdentityCredential if no argument provided

# ===============================
# Paths
# ===============================
WORK_DIR_CONFIG="$WORK_DIR/src/config"
UTILS_DIR="$WORK_DIR/src/utils/crypto"
TARGET_DIR="${TARGET_DIR:-/tmp}"

# ===============================
# Get User Access Token
# ===============================
log "Requesting access token for user '$USER_FRANCIS_NAME'..."

response=$(curl -k -s -o "$TARGET_DIR/response.json" -w "%{http_code}" -X POST \
  "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -d "client_id=openid4vc-rest-api" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$USER_FRANCIS_NAME" \
  -d "password=$USER_FRANCIS_PASSWORD" \
  -d "grant_type=password" \
  -d "scope=openid")

if [ "$response" -ne 200 ]; then
  error "Failed to retrieve user token (HTTP $response)"
  exit 1
fi

USER_ACCESS_TOKEN=$(jq -r '.access_token' < "$TARGET_DIR/response.json")
success "User Access Token retrieved."

# ===============================
# Credential Offer
# ===============================
log "Requesting credential offer for '$CREDENTIAL_TYPE'..."

CREDENTIAL_OFFER_LINK=$(curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential-offer-uri?credential_configuration_id=$CREDENTIAL_TYPE" \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' | jq -r '"\(.issuer)\(.nonce)"')

if [ -z "$CREDENTIAL_OFFER_LINK" ] || [ "$CREDENTIAL_OFFER_LINK" == "null" ]; then
  error "Failed to retrieve CREDENTIAL_OFFER_LINK"
  exit 1
fi

success "Credential Offer Link: $CREDENTIAL_OFFER_LINK"

CREDENTIAL_OFFER=$(curl -k -s "$CREDENTIAL_OFFER_LINK" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN")

log "Credential Offer retrieved."

PRE_AUTHORIZED_CODE=$(echo "$CREDENTIAL_OFFER" | jq -r '."grants"."urn:ietf:params:oauth:grant-type:pre-authorized_code"."pre-authorized_code"')

if [ -z "$PRE_AUTHORIZED_CODE" ] || [ "$PRE_AUTHORIZED_CODE" == "null" ]; then
  error "Failed to extract PRE_AUTHORIZED_CODE"
  exit 1
fi

success "Pre-Authorized Code: $PRE_AUTHORIZED_CODE"

# ===============================
# Get Nonce
# ===============================
log "Requesting nonce from Keycloak..."

C_NONCE=$(curl -k -s -X POST "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/protocol/oid4vc/nonce" | jq -r '.c_nonce')

if [ -z "$C_NONCE" ] || [ "$C_NONCE" == "null" ]; then
  error "Failed to retrieve C_NONCE"
  exit 1
fi

success "C_NONCE: $C_NONCE"

# ===============================
# Obtain Credential Bearer Token
# ===============================
log "Requesting credential bearer token..."

CREDENTIAL_BEARER_TOKEN=$(curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code' \
  -d "pre-authorized_code=$PRE_AUTHORIZED_CODE" \
  -d "client_id=openid4vc-rest-api" \
  -d "client_secret=$CLIENT_SECRET")

CREDENTIAL_ACCESS_TOKEN=$(echo "$CREDENTIAL_BEARER_TOKEN" | jq -r '.access_token')

if [ -z "$CREDENTIAL_ACCESS_TOKEN" ] || [ "$CREDENTIAL_ACCESS_TOKEN" == "null" ]; then
  error "Failed to retrieve credential access token"
  exit 1
fi

success "Credential Access Token retrieved."

# ===============================
# Generate Key Proof
# ===============================
log "Generating key proof..."
. "$UTILS_DIR/generate_key_proof.sh"
success "Key proof generated."

# ===============================
# Prepare Request Payload
# ===============================
REQ_BODY=$(jq \
  --arg credential_identifier "$CREDENTIAL_TYPE" \
  --arg proof_jwt "$USER_KEY_PROOF" \
  '.credential_identifier = $credential_identifier | .proofs.jwt = [$proof_jwt]' \
  "$WORK_DIR_CONFIG/credential_request_body.json")

# ===============================
# Obtain Credential
# ===============================
log "Requesting credential '$CREDENTIAL_TYPE'..."

CREDENTIAL=$(curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $CREDENTIAL_ACCESS_TOKEN" \
  -d "$REQ_BODY")

if [ -z "$CREDENTIAL" ] || [ "$CREDENTIAL" == "null" ]; then
  error "Failed to retrieve credential."
  exit 1
fi

success "Credential '$CREDENTIAL_TYPE' retrieved successfully!"
echo -e "\n$CREDENTIAL\n"
