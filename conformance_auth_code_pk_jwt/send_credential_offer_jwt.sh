#!/bin/bash

# OID4VCI Conformance Test - Send Credential Offer Script (JWT Client)
# This script sends the credential offer to the OpenID Foundation conformance test suite
# using the JWT client configuration for authorization code flow

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source load_env.sh from the parent directory
source "$SCRIPT_DIR/../load_env.sh"

# Configuration
NGROK_URL="https://7baf29ab3443.ngrok-free.app"
KEYCLOAK_REALM_URL="$NGROK_URL/realms/oid4vc-vci"
TEST_SUITE_BASE_URL="https://demo.certification.openid.net/test/a/keycloak-oid4vci-test"

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

log_message "=== OID4VCI Conformance Test - Send Credential Offer (JWT Client) ==="
log_message "Keycloak URL: $KEYCLOAK_REALM_URL"
log_message "Test Suite URL: $TEST_SUITE_BASE_URL"
log_message "Client ID: openid4vc-rest-api-jwt"
log_message "Credential Configuration ID: IdentityCredential"
log_message ""

# Function to wait for user input
wait_for_user() {
    echo ""
    echo "Press Enter to continue to the next step..."
    read -r
    echo ""
}

# Step 1: Get a fresh user access token
log_message "Step 1: Getting fresh user access token..."
log_message "Running: curl -k -s -X POST $NGROK_URL/realms/oid4vc-vci/protocol/openid-connect/token ..."
wait_for_user

USER_ACCESS_TOKEN=$(curl -k -s -X POST $NGROK_URL/realms/oid4vc-vci/protocol/openid-connect/token \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=uArydomqOymeF0tBrtipkPYujNNUuDlt" \
    -d "username=francis" \
    -d "password=francis" \
    -d "grant_type=password" \
    -d "scope=openid" | jq -r '.access_token')

if [ "$USER_ACCESS_TOKEN" = "null" ] || [ -z "$USER_ACCESS_TOKEN" ]; then
    exit_with_error "Failed to get user access token"
fi

log_message "✅ Got fresh user access token: ${USER_ACCESS_TOKEN:0:50}..."

# Step 2: Create authorization code flow credential offer
log_message ""
log_message "Step 2: Creating authorization code flow credential offer..."
log_message "This will create a credential offer that uses authorization_code grant type"
wait_for_user

# Create a credential offer for authorization code flow
CREDENTIAL_OFFER=$(cat <<EOF
{
  "credential_issuer": "$KEYCLOAK_REALM_URL",
  "credential_configuration_ids": ["IdentityCredential"],
  "grants": {
    "authorization_code": {
      "authorization_server": "$KEYCLOAK_REALM_URL"
    }
  }
}
EOF
)

log_message "Authorization Code Flow Credential Offer:"
echo $CREDENTIAL_OFFER | jq .

# Step 3: URL encode the credential offer and send to test suite
log_message ""
log_message "Step 3: URL encoding and sending credential offer to test suite..."
CREDENTIAL_OFFER_ENCODED=$(echo "$CREDENTIAL_OFFER" | jq -c . | jq -rR @uri)

log_message "Encoded credential offer: ${CREDENTIAL_OFFER_ENCODED:0:100}..."
log_message "Sending to: $TEST_SUITE_BASE_URL/credential_offer"
log_message "Running: curl -k -s -X POST \"$TEST_SUITE_BASE_URL/credential_offer?credential_offer=\$CREDENTIAL_OFFER_ENCODED\" ..."
wait_for_user

log_message "Sending credential offer to test suite..."
RESPONSE=$(curl -k -s -X POST "$TEST_SUITE_BASE_URL/credential_offer?credential_offer=$CREDENTIAL_OFFER_ENCODED" \
    -H "Content-Type: application/json")

log_message "Test suite response:"
echo $RESPONSE

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
    log_message "3. The test will use client_id: openid4vc-rest-api-jwt"
    log_message "4. The test will use Private Key JWT authentication with ES256"
    log_message ""
    log_message "🔗 Test Suite Dashboard: $TEST_SUITE_BASE_URL"
fi

# Summary
log_message ""
log_message "=== Script Completed ==="
log_message "🔗 Key URLs:"
log_message "- Test Suite: $TEST_SUITE_BASE_URL"
log_message "- Keycloak Admin: $NGROK_URL/admin"
log_message "- Credential Issuer: $KEYCLOAK_REALM_URL/.well-known/openid-credential-issuer"
log_message ""
log_message "📋 JWT Client Configuration:"
log_message "- Client ID: openid4vc-rest-api-jwt"
log_message "- Grant Type: authorization_code"
log_message "- Authentication: Private Key JWT (client-jwt)"
log_message "- Key ID: key-1"
log_message "- Signing Algorithm: ES256 (ECDSA P-256)"
log_message "- Redirect URI: https://demo.certification.openid.net/test/a/keycloak-oid4vci-test/callback"
log_message ""
