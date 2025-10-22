#!/bin/bash
set -e

# ===============================
# Load Environment
# ===============================
if [ ! -f "$(dirname "$0")/../../load_env.sh" ]; then
  echo "❌ ERROR: load_env.sh not found!"
  exit 1
fi

. "$(dirname "$0")/../../load_env.sh"

# ===============================
# Color Codes
# ===============================
INFO_COLOR="\033[1;34m"     # Blue
WARN_COLOR="\033[1;33m"     # Yellow
ERROR_COLOR="\033[1;31m"    # Red
SUCCESS_COLOR="\033[1;32m"  # Green
RESET_COLOR="\033[0m"

# ===============================
# Logging Helpers
# ===============================
log_info() { echo -e "${INFO_COLOR}[INFO]${RESET_COLOR} $1"; }
log_warn() { echo -e "${WARN_COLOR}[WARN]${RESET_COLOR} $1"; }
log_error() { echo -e "${ERROR_COLOR}[ERROR]${RESET_COLOR} $1"; }
log_success() { echo -e "${SUCCESS_COLOR}[SUCCESS]${RESET_COLOR} $1"; }

# ===============================
# Argument Validation
# ===============================
if [ -z "$1" ]; then
  log_error "Usage: $0 <CREDENTIAL_TYPE>"
  log_warn "Example: $0 IdentityCredential"
  exit 1
fi

CREDENTIAL_TYPE="$1"

# ===============================
# Paths
# ===============================
WORK_DIR="$(dirname "$0")/../config"
UTILS_DIR="$(dirname "$0")/../utils/crypto"
TARGET_DIR="${TARGET_DIR:-/tmp}"

# ===============================
# Get User Token
# ===============================
log_info "Requesting access token for user '$USER_FRANCIS_NAME'..."

response=$(curl -k -s -o "$TARGET_DIR/response.json" -w "%{http_code}" -X POST \
  "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -d "client_id=openid4vc-rest-api" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$USER_FRANCIS_NAME" \
  -d "password=$USER_FRANCIS_PASSWORD" \
  -d "grant_type=password" \
  -d "scope=openid")

if [ "$response" -ne 200 ]; then
  log_error "Failed to retrieve user token (HTTP $response)"
  exit 1
fi

USER_ACCESS_TOKEN=$(jq -r '.access_token' < "$TARGET_DIR/response.json")
log_success "User Access Token retrieved."

# ===============================
# Credential Offer
# ===============================
log_info "Requesting credential offer for '$CREDENTIAL_TYPE'..."

CREDENTIAL_OFFER_LINK=$(curl -k -s "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential-offer-uri?credential_configuration_id=$CREDENTIAL_TYPE" \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' | jq -r '"\(.issuer)\(.nonce)"')

if [ -z "$CREDENTIAL_OFFER_LINK" ] || [ "$CREDENTIAL_OFFER_LINK" == "null" ]; then
  log_error "Failed to retrieve CREDENTIAL_OFFER_LINK"
  exit 1
fi

log_success "Credential Offer Link: $CREDENTIAL_OFFER_LINK"

CREDENTIAL_OFFER=$(curl -k -s "$CREDENTIAL_OFFER_LINK" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN")

log_info "Credential Offer retrieved."

PRE_AUTHORIZED_CODE=$(echo "$CREDENTIAL_OFFER" | jq -r '."grants"."urn:ietf:params:oauth:grant-type:pre-authorized_code"."pre-authorized_code"')

if [ -z "$PRE_AUTHORIZED_CODE" ] || [ "$PRE_AUTHORIZED_CODE" == "null" ]; then
  log_error "Failed to extract PRE_AUTHORIZED_CODE"
  exit 1
fi

log_success "Pre-Authorized Code: $PRE_AUTHORIZED_CODE"

# ===============================
# Get Nonce
# ===============================
log_info "Requesting nonce from Keycloak..."

C_NONCE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/nonce" | jq -r '.c_nonce')

if [ -z "$C_NONCE" ] || [ "$C_NONCE" == "null" ]; then
  log_error "Failed to retrieve C_NONCE"
  exit 1
fi

log_success "C_NONCE: $C_NONCE"

# ===============================
# Obtain Credential Bearer Token
# ===============================
log_info "Requesting credential bearer token..."

CREDENTIAL_BEARER_TOKEN=$(curl -k -s "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code' \
  -d "pre-authorized_code=$PRE_AUTHORIZED_CODE" \
  -d "client_id=openid4vc-rest-api" \
  -d "client_secret=$CLIENT_SECRET")

CREDENTIAL_ACCESS_TOKEN=$(echo "$CREDENTIAL_BEARER_TOKEN" | jq -r '.access_token')

if [ -z "$CREDENTIAL_ACCESS_TOKEN" ] || [ "$CREDENTIAL_ACCESS_TOKEN" == "null" ]; then
  log_error "Failed to retrieve credential access token"
  exit 1
fi

log_success "Credential Access Token retrieved."

# ===============================
# Generate Key Proof
# ===============================
log_info "Generating key proof..."
. "$UTILS_DIR/generate_key_proof.sh"
log_success "Key proof generated."

# ===============================
# Prepare Request Payload
# ===============================
REQ_BODY=$(jq \
  --arg credential_identifier "$CREDENTIAL_TYPE" \
  --arg proof_jwt "$USER_KEY_PROOF" \
  '.credential_identifier = $credential_identifier | .proofs.jwt = [$proof_jwt]' \
  "$WORK_DIR/credential_request_body.json")

# ===============================
# Obtain Credential
# ===============================
log_info "Requesting credential '$CREDENTIAL_TYPE'..."

CREDENTIAL=$(curl -k -s "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $CREDENTIAL_ACCESS_TOKEN" \
  -d "$REQ_BODY")

if [ -z "$CREDENTIAL" ] || [ "$CREDENTIAL" == "null" ]; then
  log_error "Failed to retrieve credential."
  exit 1
fi

log_success "Credential '$CREDENTIAL_TYPE' retrieved successfully!"
echo -e "\n$CREDENTIAL\n"
