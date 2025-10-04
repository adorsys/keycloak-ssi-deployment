#!/bin/bash

# OID4VCI Conformance Test - Send Credential Offer Script (Interactive)
# This script sends the credential offer to the OpenID Foundation conformance test suite
# Runs one command at a time for better debugging and control
#
# Expected behavior:
# - The test suite will receive the credential offer successfully
# - It may return a 400 error about missing authorization_details in token response
# - This is expected and helps identify configuration issues in Keycloak

# Configuration
NGROK_URL="https://7baf29ab3443.ngrok-free.app"
KEYCLOAK_REALM_URL="$NGROK_URL/realms/oid4vc-vci"
TEST_SUITE_BASE_URL="https://demo.certification.openid.net/test/a/keycloak-oid4vci-test"

echo "=== OID4VCI Conformance Test - Send Credential Offer (Interactive) ==="
echo "Keycloak URL: $KEYCLOAK_REALM_URL"
echo "Test Suite URL: $TEST_SUITE_BASE_URL"
echo ""

# Function to wait for user input
wait_for_user() {
    echo ""
    echo "Press Enter to continue to the next step..."
    read -r
    echo ""
}

# Step 1: Get a fresh user access token
echo "Step 1: Getting fresh user access token..."
echo "Running: curl -k -s -X POST $NGROK_URL/realms/oid4vc-vci/protocol/openid-connect/token ..."
wait_for_user

USER_ACCESS_TOKEN=$(curl -k -s -X POST $NGROK_URL/realms/oid4vc-vci/protocol/openid-connect/token \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=uArydomqOymeF0tBrtipkPYujNNUuDlt" \
    -d "username=francis" \
    -d "password=francis" \
    -d "grant_type=password" \
    -d "scope=openid" | jq -r '.access_token')

if [ "$USER_ACCESS_TOKEN" = "null" ] || [ -z "$USER_ACCESS_TOKEN" ]; then
    echo "❌ Failed to get user access token"
    exit 1
fi

echo "✅ Got fresh user access token: ${USER_ACCESS_TOKEN:0:50}..."

# Step 2: Get a fresh credential offer URI
echo ""
echo "Step 2: Getting fresh credential offer URI..."
echo "Running: curl -k -s -H \"Authorization: Bearer \$USER_ACCESS_TOKEN\" ..."
wait_for_user

CREDENTIAL_OFFER_URI=$(curl -k -s -H "Authorization: Bearer $USER_ACCESS_TOKEN" "$NGROK_URL/realms/oid4vc-vci/protocol/oid4vc/credential-offer-uri?credential_configuration_id=IdentityCredential&type=uri")

echo "Fresh Credential Offer URI Response:"
echo $CREDENTIAL_OFFER_URI | jq .

# Step 3: Extract the nonce and get the actual credential offer
echo ""
echo "Step 3: Extracting nonce and getting credential offer..."
NONCE=$(echo $CREDENTIAL_OFFER_URI | jq -r '.nonce')

if [ "$NONCE" = "null" ] || [ -z "$NONCE" ]; then
    echo "❌ Failed to extract nonce from credential offer URI"
    exit 1
fi

echo "Extracted nonce: $NONCE"
echo "Running: curl -k -s \"$NGROK_URL/realms/oid4vc-vci/protocol/oid4vc/credential-offer/\$NONCE\""
wait_for_user

CREDENTIAL_OFFER=$(curl -k -s "$NGROK_URL/realms/oid4vc-vci/protocol/oid4vc/credential-offer/$NONCE")

echo "Fresh Credential Offer:"
echo $CREDENTIAL_OFFER | jq .

# Step 4: Construct the credential offer with ngrok URLs
echo ""
echo "Step 4: Constructing credential offer with ngrok URLs..."
CREDENTIAL_OFFER_JSON=$(echo $CREDENTIAL_OFFER | jq --arg issuer "$KEYCLOAK_REALM_URL" '.credential_issuer = $issuer')

echo "Credential Offer to send:"
echo $CREDENTIAL_OFFER_JSON | jq .

# Step 5: URL encode the credential offer and send to test suite
echo ""
echo "Step 5: URL encoding and sending credential offer to test suite..."
CREDENTIAL_OFFER_ENCODED=$(echo "$CREDENTIAL_OFFER_JSON" | jq -c . | jq -rR @uri)

echo "Encoded credential offer: ${CREDENTIAL_OFFER_ENCODED:0:100}..."
echo "Sending to: $TEST_SUITE_BASE_URL/credential_offer"
echo "Running: curl -k -s -X POST \"$TEST_SUITE_BASE_URL/credential_offer?credential_offer=\$CREDENTIAL_OFFER_ENCODED\" ..."
wait_for_user

echo "Sending credential offer to test suite..."
RESPONSE=$(curl -k -s -X POST "$TEST_SUITE_BASE_URL/credential_offer?credential_offer=$CREDENTIAL_OFFER_ENCODED" \
    -H "Content-Type: application/json")

echo "Test suite response:"
echo $RESPONSE

# Check the response
echo ""
echo "=== Response Analysis ==="
if echo "$RESPONSE" | grep -q "authorization_details"; then
    echo "✅ SUCCESS: Test suite received the credential offer!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Check the test suite dashboard for detailed results"
    echo "2. This helps identify what needs to be fixed in your Keycloak setup"
    echo ""
    echo "🔗 Test Suite Dashboard: $TEST_SUITE_BASE_URL"
elif echo "$RESPONSE" | grep -q "error"; then
    echo "⚠️  Test suite returned an error:"
    echo $RESPONSE | jq .
else
    echo "✅ Credential offer sent successfully!"
    echo "The test suite should now be processing the credential offer."
    echo ""
    echo "📋 Next Steps:"
    echo "1. Check the test suite dashboard"
    echo ""
    echo "🔗 Test Suite Dashboard: $TEST_SUITE_BASE_URL"
fi

# Summary
echo ""
echo "=== Script Completed ==="
echo "🔗 Key URLs:"
echo "- Test Suite: $TEST_SUITE_BASE_URL"
echo "- Keycloak Admin: $NGROK_URL/admin"
echo "- Credential Issuer: $KEYCLOAK_REALM_URL/.well-known/openid-credential-issuer"
