#!/bin/bash

# Source common environment variables
source load_env.sh

# Function to log messages with consistent formatting and spacing
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

# Function to generate PKCE (Proof Key for Code Exchange) parameters:
# - code_verifier: high-entropy cryptographic random string
# - code_challenge: derived from code_verifier using SHA-256 and base64url encoding
generate_pkce() {
    local code_verifier
    code_verifier=$(openssl rand -base64 96 | tr -d '+/=' | tr -d '\n' | cut -c -128)

    local code_challenge
    code_challenge=$(echo -n "$code_verifier" | openssl dgst -sha256 -binary |
        openssl base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n')

    echo "$code_verifier" "$code_challenge"
}

log_message "Waiting for Keycloak at ${KEYCLOAK_ADMIN_ADDR}..."
until curl -s -k "${KEYCLOAK_ADMIN_ADDR}/health" > /dev/null; do
    sleep 5
done
log_message "Keycloak is running."

# Authenticate admin via kcadm
log_message "Configuring Keycloak admin credentials..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE"

# Check if admin credentials are already configured
if ! $KC_INSTALL_DIR/bin/kcadm.sh get realms --server "$KEYCLOAK_ADMIN_ADDR" --realm master > /dev/null 2>&1; then
    log_message "No existing admin credentials found. Configuring new credentials..."
    $KC_INSTALL_DIR/bin/kcadm.sh config credentials \
        --server "$KEYCLOAK_ADMIN_ADDR" \
        --realm master \
        --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
        --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" || exit_with_error "Failed to configure Keycloak admin credentials"
else
    log_message "Admin credentials already configured."
fi

# Check if user 'francis' exists
log_message "Verifying user 'francis'..."
if ! $KC_INSTALL_DIR/bin/kcadm.sh get users -r "$KEYCLOAK_REALM" --fields username | jq -e '.[] | select(.username=="francis")' > /dev/null; then
    exit_with_error "User 'francis' does not exist. Run 2.configure_user_4_account_client.sh first."
fi

# Generate key proof if not present
if [ ! -f "$TARGET_DIR/user_key_proof_header.json" ]; then
    log_message "Generating key proof for user..."
    source ./generate_user_key.sh || exit_with_error "Failed to generate user key proof"
fi

# Function to request credential
request_credential() {
    local credential_id=$1
    local credential_scope="$credential_id"

    local scopes="openid $credential_scope"
    log_message "=== Requesting credential: ${credential_id} ==="

    local encoded_scopes
    encoded_scopes=$(echo "$scopes" | tr -d '\n' | jq -sRr @uri)
    local issuer_state="state-$(uuidgen)"

    read code_verifier code_challenge <<< "$(generate_pkce)"
    log_message "PKCE: code_verifier=$code_verifier code_challenge=$code_challenge"

    local auth_url="${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth?response_type=code&client_id=openid4vc-rest-api&redirect_uri=https://localhost:8443/callback&scope=${encoded_scopes}&issuer_state=${issuer_state}&authorization_details=%7B%22type%22:%22openid_credential%22,%22credential_configuration_id%22:%22${credential_id}%22%7D&code_challenge=${code_challenge}&code_challenge_method=S256"

    log_message "Manual step required: Open this URL in your browser and login as 'francis'. Paste the 'code' param from the redirect URL."
    echo "$auth_url"
    read -p "Authorization code: " auth_code
    if [ -z "$auth_code" ]; then
        exit_with_error "No authorization code provided"
    fi
    log_message "Authorization code obtained: $auth_code"

    log_message "Exchanging authorization code for token..."
    local token_response
    token_response=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
        -d "grant_type=authorization_code" \
        -d "code=${auth_code}" \
        -d "client_id=openid4vc-rest-api" \
        -d "client_secret=${CLIENT_SECRET}" \
        -d "redirect_uri=https://localhost:8443/callback" \
        -d "code_verifier=${code_verifier}")

    local access_token
    access_token=$(echo "$token_response" | jq -r '.access_token')
    if [ -z "$access_token" ] || [ "$access_token" == "null" ]; then
        exit_with_error "Token exchange failed: $token_response"
    fi

    log_message "Access token obtained successfully"
    echo -e "\nACCESS_TOKEN: $access_token"
    log_message "Token scopes:"
    echo "$token_response" | jq '.scope'

    # Retrieve the c_nonce from the keycloak nonce endpoint
    C_NONCE=$(curl -k -s -X POST $KEYCLOAK_EXTERNAL_ADDR/realms/$KEYCLOAK_REALM/protocol/oid4vc/nonce | jq -r '.c_nonce')

    echo "C_NONCE: $C_NONCE"

    export CREDENTIAL_ACCESS_TOKEN="$access_token"
    log_message "Generating key proof..."
    source ./generate_key_proof.sh || exit_with_error "Failed to generate key proof"

    local req_body
    req_body=$(jq --arg credential_identifier "$credential_id" --arg proof_jwt "$USER_KEY_PROOF" \
        '.credential_identifier = $credential_identifier | .proofs.jwt = [ $proof_jwt ]' < "$WORK_DIR/credential_request_body.json")

    log_message "Request body prepared: $req_body"

    log_message "Requesting credential..."
    local credential
    credential=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/credential" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "$req_body" | jq .)

    if [ -z "$credential" ] || [ "$credential" == "null" ] || echo "$credential" | jq -e '.error' > /dev/null; then
        exit_with_error "Credential issuance failed for $credential_id. Response: $credential"
    fi

    log_message "Credential successfully issued: $credential"
}

# Run credential tests
request_credential "IdentityCredential"
request_credential "SteuerberaterCredential"

log_message "All credential request tests completed successfully."
