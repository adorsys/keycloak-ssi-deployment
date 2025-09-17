#!/bin/bash

# Test Pre-authorized Code Flow for Credential Issuance
# This script simulates the conformance test's pre-authorized code flow

set -e

# Configuration
KEYCLOAK_URL="https://localhost:8443"
REALM="oid4vc-vci"
CLIENT_ID="openid4vc-rest-api"
CLIENT_SECRET="uArydomqOymeF0tBrtipkPYujNNUuDlt"
USERNAME="francis"
PASSWORD="francis"

echo "=== Testing Pre-authorized Code Flow ==="

# Step 1: Get user access token (this is what the conformance test does)
echo "Step 1: Getting user access token..."
USER_ACCESS_TOKEN=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "username=$USERNAME" \
    -d "password=$PASSWORD" \
    -d "scope=openid profile email" | jq -r '.access_token')

if [ "$USER_ACCESS_TOKEN" = "null" ] || [ -z "$USER_ACCESS_TOKEN" ]; then
    echo "❌ Failed to get user access token"
    exit 1
fi

echo "✅ User access token obtained"

# Step 2: Get credential offer URI (this should work with user token)
echo "Step 2: Getting credential offer URI..."
CREDENTIAL_OFFER_URI=$(curl -k -s -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
    "$KEYCLOAK_URL/realms/$REALM/protocol/oid4vc/credential-offer-uri?credential_configuration_id=IdentityCredential&type=uri")

echo "Credential offer URI response:"
echo "$CREDENTIAL_OFFER_URI" | jq .

# Check if we got a valid response
if echo "$CREDENTIAL_OFFER_URI" | jq -e '.error' > /dev/null; then
    echo "❌ Failed to get credential offer URI"
    echo "Error: $(echo "$CREDENTIAL_OFFER_URI" | jq -r '.error_description // .error')"
    exit 1
fi

# Extract the credential offer URI
OFFER_URI=$(echo "$CREDENTIAL_OFFER_URI" | jq -r '.credential_offer_uri')
if [ "$OFFER_URI" = "null" ] || [ -z "$OFFER_URI" ]; then
    echo "❌ No credential offer URI in response"
    exit 1
fi

echo "✅ Credential offer URI obtained: $OFFER_URI"

# Step 3: Get the credential offer
echo "Step 3: Getting credential offer..."
CREDENTIAL_OFFER=$(curl -k -s "$OFFER_URI")

echo "Credential offer response:"
echo "$CREDENTIAL_OFFER" | jq .

# Check if we got a valid credential offer
if echo "$CREDENTIAL_OFFER" | jq -e '.error' > /dev/null; then
    echo "❌ Failed to get credential offer"
    echo "Error: $(echo "$CREDENTIAL_OFFER" | jq -r '.error_description // .error')"
    exit 1
fi

# Extract pre-authorized code
PRE_AUTHORIZED_CODE=$(echo "$CREDENTIAL_OFFER" | jq -r '.grants.pre_authorized_code.pre_authorized_code')
if [ "$PRE_AUTHORIZED_CODE" = "null" ] || [ -z "$PRE_AUTHORIZED_CODE" ]; then
    echo "❌ No pre-authorized code in credential offer"
    exit 1
fi

echo "✅ Pre-authorized code obtained: $PRE_AUTHORIZED_CODE"

# Step 4: Exchange pre-authorized code for access token
echo "Step 4: Exchanging pre-authorized code for access token..."
CREDENTIAL_ACCESS_TOKEN=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "pre-authorized_code=$PRE_AUTHORIZED_CODE")

echo "Credential access token response:"
echo "$CREDENTIAL_ACCESS_TOKEN" | jq .

# Check if we got a valid access token
if echo "$CREDENTIAL_ACCESS_TOKEN" | jq -e '.error' > /dev/null; then
    echo "❌ Failed to exchange pre-authorized code for access token"
    echo "Error: $(echo "$CREDENTIAL_ACCESS_TOKEN" | jq -r '.error_description // .error')"
    exit 1
fi

CREDENTIAL_TOKEN=$(echo "$CREDENTIAL_ACCESS_TOKEN" | jq -r '.access_token')
if [ "$CREDENTIAL_TOKEN" = "null" ] || [ -z "$CREDENTIAL_TOKEN" ]; then
    echo "❌ No access token in response"
    exit 1
fi

echo "✅ Credential access token obtained"

# Step 5: Get c_nonce for proof
echo "Step 5: Getting c_nonce..."
C_NONCE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/oid4vc/nonce" | jq -r '.c_nonce')

if [ "$C_NONCE" = "null" ] || [ -z "$C_NONCE" ]; then
    echo "❌ Failed to get c_nonce"
    exit 1
fi

echo "✅ C_nonce obtained: $C_NONCE"

# Step 6: Generate key proof
echo "Step 6: Generating key proof..."
# Set environment variables for proof generation
export CREDENTIAL_ACCESS_TOKEN="$CREDENTIAL_TOKEN"
export C_NONCE="$C_NONCE"
export KEYCLOAK_EXTERNAL_ADDR="$KEYCLOAK_URL"
export KEYCLOAK_REALM="$REALM"
export WORK_DIR="."
export TARGET_DIR="./target"
export FRANCIS_KEYSTORE_FILE="./target/francis_kc_keystore.pkcs12"
export FRANCIS_KEYSTORE_PASSWORD="francis_store_key_password"

# Generate the proof
. ./generate_key_proof.sh

# Step 7: Request credential with the credential access token
echo "Step 7: Requesting credential..."
CREDENTIAL_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/oid4vc/credential" \
    -H "Authorization: Bearer $CREDENTIAL_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"credential_configuration_id\": \"IdentityCredential\",
        \"proofs\": {
            \"jwt\": [\"$USER_KEY_PROOF\"]
        }
    }")

echo "Credential response:"
echo "$CREDENTIAL_RESPONSE" | jq .

# Check if we got a valid credential
if echo "$CREDENTIAL_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ Failed to get credential"
    echo "Error: $(echo "$CREDENTIAL_RESPONSE" | jq -r '.error_description // .error')"
    exit 1
fi

echo "✅ Credential obtained successfully!"
echo "=== Pre-authorized Code Flow Test Complete ==="
