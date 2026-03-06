#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# OID4VCI Conformance Test - Send Credential Offer Script (JWT Client)
# This script sends the credential offer to the OpenID Foundation conformance test suite
# using the JWT client configuration for authorization code flow

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source load_env.sh from the parent directory
source "$SCRIPT_DIR/../load_env.sh"

# Function to log messages
log_message() {
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to exit with error message
exit_with_error() {
    log_message "❌ ERROR: $1"
    exit 1
}

# Derive URLs from environment
# We use the public hostname to ensure consistency with Keycloak's issuer URL
KEYCLOAK_REALM_URL="$KEYCLOAK_EXTERNAL_ADDR/realms/$KEYCLOAK_REALM"
TEST_SUITE_BASE_URL="https://localhost.emobix.co.uk:9443/test/a/keycloak-oid4vci-test"

log_message "=== OID4VCI Conformance Test - Send Credential Offer (JWT Client) ==="
log_message "Keycloak URL: $KEYCLOAK_REALM_URL"
log_message "Test Suite URL: $TEST_SUITE_BASE_URL"
log_message "Client ID: openid4vc-rest-api-jwt2"
log_message "Credential Configuration ID: IdentityCredential"
log_message ""

# Function to wait for user input
wait_for_user() {
    echo ""
    echo "Press Enter to continue to the next step..."
    read -r
    echo ""
}

log_message "Step 1: Getting fresh user access token (Private Key JWT auth)..."

TOKEN_ENDPOINT="$KEYCLOAK_EXTERNAL_ADDR/realms/$KEYCLOAK_REALM/protocol/openid-connect/token"

# Generate client_assertion JWT signed with ES256
log_message "Generating client_assertion JWT..."
log_message "Audience for assertion: $TOKEN_ENDPOINT"
CLIENT_ASSERTION=$(python3 "$SCRIPT_DIR/generate_client_assertion.py" "openid4vc-rest-api-jwt2" "$TOKEN_ENDPOINT")

if [ -z "$CLIENT_ASSERTION" ]; then
    exit_with_error "Failed to generate client_assertion JWT"
fi

log_message "Client assertion generated (first 50 chars): ${CLIENT_ASSERTION:0:50}..."
log_message "Running: curl -k -s -X POST $TOKEN_ENDPOINT ..."
wait_for_user

TOKEN_RESPONSE=$(curl -k -s -X POST "$TOKEN_ENDPOINT" \
    -d "client_id=openid4vc-rest-api-jwt2" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=$CLIENT_ASSERTION" \
    -d "username=$USER_FRANCIS_NAME" \
    -d "password=$USER_FRANCIS_PASSWORD" \
    -d "grant_type=password" \
    -d "scope=openid")

USER_ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$USER_ACCESS_TOKEN" = "null" ] || [ -z "$USER_ACCESS_TOKEN" ]; then
    log_message "Token Response: $TOKEN_RESPONSE"
    exit_with_error "Failed to get user access token"
fi

log_message "✅ Got fresh user access token: ${USER_ACCESS_TOKEN:0:50}..."


# Step 2: Create a registered credential offer via Keycloak
log_message ""
log_message "Step 2: Creating registered credential offer via Keycloak..."
log_message "This will create an internal CredentialOfferState in Keycloak."
wait_for_user

# 1. First, get the offer URI (this creates the session state in Keycloak)
#    Uses the new create-credential-offer endpoint; non pre-authorized, anonymous offer.
OFFER_URI_RESPONSE=$(curl -k -s -X GET "$KEYCLOAK_REALM_URL/protocol/oid4vc/create-credential-offer?credential_configuration_id=IdentityCredential&pre_authorized=false&type=uri" \
    -H "Authorization: Bearer $USER_ACCESS_TOKEN")

NONCE=$(echo "$OFFER_URI_RESPONSE" | jq -r '.nonce')
if [ "$NONCE" = "null" ] || [ -z "$NONCE" ]; then
    exit_with_error "Failed to create offer session in Keycloak. Response: $OFFER_URI_RESPONSE"
fi

# 2. Fetch the actual Credential Offer JSON from Keycloak using the nonce
# This ensures we send the exact JSON that Keycloak expects
CREDENTIAL_OFFER=$(curl -k -s -X GET "$KEYCLOAK_EXTERNAL_ADDR/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential-offer/$NONCE")

if [ "$CREDENTIAL_OFFER" = "null" ] || [ -z "$CREDENTIAL_OFFER" ]; then
    exit_with_error "Failed to fetch credential offer JSON from Keycloak for nonce: $NONCE"
fi

log_message "✅ Fetched Registered Credential Offer from Keycloak:"
echo "$CREDENTIAL_OFFER" | jq .

# Step 3: URL encode the credential offer and send to test suite
log_message ""
log_message "Step 3: URL encoding and sending credential offer to test suite..."
CREDENTIAL_OFFER_ENCODED=$(echo "$CREDENTIAL_OFFER" | jq -c . | jq -rR @uri)

log_message "Encoded credential offer: ${CREDENTIAL_OFFER_ENCODED:0:100}..."
log_message "Sending to: $TEST_SUITE_BASE_URL/credential_offer"
wait_for_user

RESPONSE=$(curl -k -s -X POST "$TEST_SUITE_BASE_URL/credential_offer?credential_offer=$CREDENTIAL_OFFER_ENCODED" \
    -H "Content-Type: application/json")

log_message "Test suite response:"
if echo "$RESPONSE" | jq . > /dev/null 2>&1; then
    echo "$RESPONSE" | jq .
else
    echo "$RESPONSE"
fi

# Check the response
log_message ""
log_message "=== Response Analysis ==="
if echo "$RESPONSE" | grep -q "authorization_details"; then
    log_message "✅ SUCCESS: Test suite received the credential offer!"
    log_message ""
    log_message "📋 Next Steps:"
    log_message "1. Check the test suite dashboard for detailed results"
    log_message "2. The test suite will now use the JWT client for authentication"
    log_message ""
    log_message "🔗 Test Suite Dashboard: $TEST_SUITE_BASE_URL"
elif echo "$RESPONSE" | grep -q "error"; then
    log_message "⚠️  Test suite returned an error:"
    echo $RESPONSE | jq .
else
    log_message "✅ Authorization code flow credential offer sent successfully!"
    log_message "The test suite should now be processing the authorization code flow with JWT client."
    log_message ""
    log_message "📋 Next Steps:"
    log_message "1. Check the test suite dashboard"
    log_message "2. The test will use authorization_code grant type"
    log_message "3. The test will use client_id: openid4vc-rest-api-jwt2"
    log_message "4. The test will use Private Key JWT authentication with ES256"
    log_message ""
    log_message "🔗 Test Suite Dashboard: $TEST_SUITE_BASE_URL"
fi

# Summary
log_message ""
log_message "=== Script Completed ==="
log_message "🔗 Key URLs:"
log_message "- Test Suite: $TEST_SUITE_BASE_URL"
log_message "- Keycloak Admin: $KEYCLOAK_EXTERNAL_ADDR/admin"
log_message "- Credential Issuer: $KEYCLOAK_REALM_URL/.well-known/openid-credential-issuer"
log_message ""
log_message "📋 JWT Client Configuration:"
log_message "- Client ID: openid4vc-rest-api-jwt2"
log_message "- Grant Type: authorization_code"
log_message "- Authentication: Private Key JWT (client-jwt)"
log_message "- Key ID: key-1"
log_message "- Signing Algorithm: ES256 (ECDSA P-256)"
log_message "- Redirect URI: https://demo.certification.openid.net/test/a/keycloak-oid4vci-test/callback"
log_message ""
