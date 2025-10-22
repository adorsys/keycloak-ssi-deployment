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
# Paths
# ===============================
WORK_DIR="$(dirname "$0")/../config"
UTILS_DIR="$(dirname "$0")/../utils/crypto"
TARGET_DIR="${TARGET_DIR:-/tmp}"

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
# Configure Admin
# ===============================
log_info "Configuring Keycloak admin credentials..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE"

if ! $KC_INSTALL_DIR/bin/kcadm.sh get realms --server "$KEYCLOAK_URL" --realm master > /dev/null 2>&1; then
  log_info "No existing admin credentials found. Configuring new credentials..."
  $KC_INSTALL_DIR/bin/kcadm.sh config credentials \
    --server "$KEYCLOAK_URL" \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" || {
      log_error "Failed to configure Keycloak admin credentials"
      exit 1
    }
else
  log_success "Admin credentials already configured."
fi

# ===============================
# Check User 'francis'
# ===============================
log_info "Verifying user 'francis'..."
if ! $KC_INSTALL_DIR/bin/kcadm.sh get users -r "$KEYCLOAK_REALM" --fields username | jq -e '.[] | select(.username=="francis")' > /dev/null; then
  log_error "User 'francis' does not exist. Run 2.configure_user_4_account_client.sh first."
  exit 1
fi
log_success "User 'francis' found."

# ===============================
# Generate Key Proof if Missing
# ===============================
if [ ! -f "$UTILS_DIR/generate_user_key.sh" ]; then
  log_error "Missing $UTILS_DIR/generate_user_key.sh"
  exit 1
fi

if [ ! -f "$TARGET_DIR/user_key_proof_header.json" ]; then
  log_info "Generating key proof for user..."
  . "$UTILS_DIR/generate_user_key.sh" || {
    log_error "Failed to generate user key proof"
    exit 1
  }
  log_success "User key proof generated."
fi

# ===============================
# PKCE Generator
# ===============================
generate_pkce() {
  local code_verifier
  code_verifier=$(openssl rand -base64 96 | tr -d '+/=' | cut -c -128)
  local code_challenge
  code_challenge=$(echo -n "$code_verifier" | openssl dgst -sha256 -binary |
    openssl base64 | tr '+/' '-_' | tr -d '=')
  echo "$code_verifier" "$code_challenge"
}

# ===============================
# Request Credential via Auth Code Flow
# ===============================
request_credential() {
  local credential_id="$1"
  local scopes="openid $credential_id"
  log_info "=== Requesting credential: ${credential_id} ==="

  read code_verifier code_challenge <<< "$(generate_pkce)"
  log_info "PKCE generated successfully."

  local encoded_scopes
  encoded_scopes=$(echo "$scopes" | jq -sRr @uri)
  local issuer_state="state-$(uuidgen)"

  local auth_url="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth?response_type=code&client_id=openid4vc-rest-api&redirect_uri=https://localhost:8443/callback&scope=${encoded_scopes}&issuer_state=${issuer_state}&authorization_details=%7B%22type%22:%22openid_credential%22,%22credential_configuration_id%22:%22${credential_id}%22%7D&code_challenge=${code_challenge}&code_challenge_method=S256"

  log_warn "Manual step required: Open the following URL in your browser and login as 'francis':"
  echo -e "\n$auth_url\n"
  read -p "Paste the 'code' parameter from the redirect URL: " auth_code

  if [ -z "$auth_code" ]; then
    log_error "No authorization code provided. Exiting."
    exit 1
  fi
  log_success "Authorization code obtained."

  log_info "Exchanging authorization code for token..."
  local token_response
  token_response=$(curl -s -k -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
    -d "grant_type=authorization_code" \
    -d "code=${auth_code}" \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "redirect_uri=https://localhost:8443/callback" \
    -d "code_verifier=${code_verifier}")

  local access_token
  access_token=$(echo "$token_response" | jq -r '.access_token')
  if [ -z "$access_token" ] || [ "$access_token" == "null" ]; then
    log_error "Token exchange failed: $token_response"
    exit 1
  fi
  log_success "Access token obtained successfully."

  # Retrieve nonce
  log_info "Retrieving nonce..."
  C_NONCE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/nonce" | jq -r '.c_nonce')
  if [ -z "$C_NONCE" ]; then
    log_error "Failed to retrieve C_NONCE"
    exit 1
  fi
  log_success "C_NONCE: $C_NONCE"

  # Generate key proof
  log_info "Generating key proof..."
  . "$UTILS_DIR/generate_key_proof.sh" || {
    log_error "Failed to generate key proof"
    exit 1
  }
  log_success "Key proof generated."

  # Prepare credential request
  local req_body
  req_body=$(jq --arg credential_identifier "$credential_id" --arg proof_jwt "$USER_KEY_PROOF" \
    '.credential_identifier = $credential_identifier | .proofs.jwt = [ $proof_jwt ]' \
    "$WORK_DIR/credential_request_body.json")

  log_info "Requesting credential..."
  local credential
  credential=$(curl -s -k -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/credential" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    -d "$req_body" | jq .)

  if [ -z "$credential" ] || [ "$credential" == "null" ] || echo "$credential" | jq -e '.error' > /dev/null; then
    log_error "Credential issuance failed for $credential_id. Response: $credential"
    exit 1
  fi

  log_success "Credential '$credential_id' successfully issued."
  echo "$credential"
}

# ===============================
# Execute
# ===============================
request_credential "$CREDENTIAL_TYPE"
log_success "Credential request process completed successfully!"
