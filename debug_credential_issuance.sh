#!/bin/bash

# Debug script for credential issuance issues
# This script will help identify why the credential response contains an "error" key

# Source common env variables
. load_env.sh

echo "=== Credential Issuance Debug Script ==="
echo ""

# 1. Check if Keycloak is running
echo "1. Checking Keycloak status..."
if curl -s -k "${KEYCLOAK_ADMIN_ADDR}/health" > /dev/null; then
    echo "✅ Keycloak is running"
else
    echo "❌ Keycloak is not accessible at ${KEYCLOAK_ADMIN_ADDR}"
    exit 1
fi
echo ""

# 2. Check client configuration
echo "2. Checking openid4vc-rest-api client configuration..."
CLIENT_CONFIG=$(curl -s -k -X GET "${KEYCLOAK_ADMIN_ADDR}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
        -d "grant_type=password" | jq -r .access_token)" | \
    jq -r '.[] | select(.clientId=="openid4vc-rest-api")')

if [ -z "$CLIENT_CONFIG" ] || [ "$CLIENT_CONFIG" == "null" ]; then
    echo "❌ Client 'openid4vc-rest-api' not found"
    exit 1
else
    echo "✅ Client found"
    
    # Check if oid4vci is enabled
    OID4VCI_ENABLED=$(echo "$CLIENT_CONFIG" | jq -r '.attributes."oid4vci.enabled" // "false"')
    if [ "$OID4VCI_ENABLED" == "true" ]; then
        echo "✅ OID4VCI is enabled for the client"
    else
        echo "❌ OID4VCI is NOT enabled for the client"
        echo "   Set 'oid4vci.enabled' to 'true' in client attributes"
    fi
    
    # Check JWKS configuration
    JWKS=$(echo "$CLIENT_CONFIG" | jq -r '.attributes.jwks // "not_set"')
    if [ "$JWKS" != "not_set" ] && [ "$JWKS" != "null" ]; then
        echo "✅ JWKS is configured"
    else
        echo "❌ JWKS is NOT configured"
        echo "   Configure JWKS in client advanced settings"
    fi
fi
echo ""

# 3. Check credential scopes
echo "3. Checking credential scopes..."
SCOPES=$(echo "$CLIENT_CONFIG" | jq -r '.optionalClientScopes[]? // empty')
if [ -n "$SCOPES" ]; then
    echo "✅ Client has optional scopes:"
    echo "$SCOPES" | while read scope; do
        echo "   - $scope"
    done
else
    echo "❌ No optional client scopes found"
    echo "   Assign credential scopes to the client"
fi
echo ""

# 4. Test credential issuer metadata
echo "4. Testing credential issuer metadata endpoint..."
METADATA_RESPONSE=$(curl -s -k "${KEYCLOAK_EXTERNAL_ADDR}/realms/${KEYCLOAK_REALM}/.well-known/openid-credential-issuer")
if echo "$METADATA_RESPONSE" | jq -e '.credential_endpoint' > /dev/null; then
    echo "✅ Credential issuer metadata is accessible"
    CREDENTIAL_TYPES=$(echo "$METADATA_RESPONSE" | jq -r '.credentials_supported | keys[]')
    echo "   Supported credential types:"
    echo "$CREDENTIAL_TYPES" | while read type; do
        echo "   - $type"
    done
else
    echo "❌ Credential issuer metadata is not accessible or invalid"
    echo "   Response: $METADATA_RESPONSE"
fi
echo ""

# 5. Test a simple credential request
echo "5. Testing credential request flow..."

# Get access token
echo "   Getting access token..."
ACCESS_TOKEN_RESPONSE=$(curl -s -k -X POST "${KEYCLOAK_EXTERNAL_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "username=${USER_FRANCIS_NAME}" \
    -d "password=${USER_FRANCIS_PASSWORD}" \
    -d "grant_type=password" \
    -d "scope=openid IdentityCredential")

ACCESS_TOKEN=$(echo "$ACCESS_TOKEN_RESPONSE" | jq -r '.access_token // "null"')
if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    echo "   Response: $ACCESS_TOKEN_RESPONSE"
    exit 1
else
    echo "✅ Access token obtained"
fi

# Get c_nonce
echo "   Getting c_nonce..."
C_NONCE_RESPONSE=$(curl -s -k -X POST "${KEYCLOAK_EXTERNAL_ADDR}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/nonce")
C_NONCE=$(echo "$C_NONCE_RESPONSE" | jq -r '.c_nonce // "null"')
if [ "$C_NONCE" == "null" ] || [ -z "$C_NONCE" ]; then
    echo "❌ Failed to get c_nonce"
    echo "   Response: $C_NONCE_RESPONSE"
    exit 1
else
    echo "✅ C_nonce obtained: $C_NONCE"
fi

# Generate key proof
echo "   Generating key proof..."
export CREDENTIAL_ACCESS_TOKEN="$ACCESS_TOKEN"
export C_NONCE="$C_NONCE"
source ./generate_key_proof.sh
if [ -z "$USER_KEY_PROOF" ]; then
    echo "❌ Failed to generate key proof"
    exit 1
else
    echo "✅ Key proof generated"
fi

# Test credential request
echo "   Testing credential request..."
CREDENTIAL_REQUEST_BODY=$(jq --arg credential_identifier "IdentityCredential" --arg proof_jwt "$USER_KEY_PROOF" \
    '.credential_identifier = $credential_identifier | .proofs.jwt = [$proof_jwt]' < "$WORK_DIR/credential_request_body.json")

CREDENTIAL_RESPONSE=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/credential" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$CREDENTIAL_REQUEST_BODY")

echo "   Credential response:"
echo "$CREDENTIAL_RESPONSE" | jq .

# Check for error
if echo "$CREDENTIAL_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ Credential request failed with error:"
    echo "$CREDENTIAL_RESPONSE" | jq '.error'
    echo ""
    echo "Error description:"
    echo "$CREDENTIAL_RESPONSE" | jq '.error_description // "No description provided"'
else
    echo "✅ Credential request successful"
fi

echo ""
echo "=== Debug Complete ==="
