#!/bin/bash

# Consolidated credential retrieval script
# Usage: ./retrieve_credential.sh <credential_type>
# Supported types: IdentityCredential, KMACredential, SteuerberaterCredential

# Source common environment variables
. scripts/utils/load_env.sh

set -euo pipefail

# Function to show usage
show_usage() {
    echo "Usage: $0 <credential_type>"
    echo ""
    echo "Supported credential types:"
    echo "  - IdentityCredential"
    echo "  - KMACredential" 
    echo "  - SteuerberaterCredential"
    echo ""
    echo "Examples:"
    echo "  $0 IdentityCredential"
    echo "  $0 KMACredential"
    echo "  $0 SteuerberaterCredential"
}

# Check if credential type is provided
if [ $# -eq 0 ]; then
    echo "Error: Credential type is required"
    show_usage
    exit 1
fi

CREDENTIAL_TYPE="$1"

# Validate credential type
case "$CREDENTIAL_TYPE" in
    "IdentityCredential"|"KMACredential"|"SteuerberaterCredential")
        echo "Retrieving credential type: $CREDENTIAL_TYPE"
        ;;
    *)
        echo "Error: Invalid credential type '$CREDENTIAL_TYPE'"
        show_usage
        exit 1
        ;;
esac

# Source common env variables
. "$(dirname "$0")/../utils/load_env.sh"

echo "Starting credential retrieval for: $CREDENTIAL_TYPE"

# Retrieve the bearer token
response=$(curl -k -s -o $TARGET_DIR/response.json -w "%{http_code}" -X POST $KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "username=$USER_FRANCIS_NAME" \
    -d "password=$USER_FRANCIS_PASSWORD" \
    -d "grant_type=password" \
    -d "scope=openid")

http_code=$(tail -n 1 <<< "$response")

if [ "$http_code" -ne 200 ]; then
    echo "Error: Server returned status code $http_code"
    exit 1
fi

USER_ACCESS_TOKEN=$(jq -r '.access_token' < $TARGET_DIR/response.json )

echo -e "Bearer Token: $USER_ACCESS_TOKEN \n"

# Retrieve link to the credential offer
CREDENTIAL_OFFER_LINK=$(curl -k -s $KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential-offer-uri?credential_configuration_id=$CREDENTIAL_TYPE \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $USER_ACCESS_TOKEN" | jq -r '"\(.issuer)\(.nonce)"')

# Stop if CREDENTIAL_OFFER_LINK is not retrieved
if [ -z "$CREDENTIAL_OFFER_LINK" ]; then
    echo "Failed to retrieve CREDENTIAL_OFFER_LINK"
    exit 1
fi

echo -e "Credential Offer Link: $CREDENTIAL_OFFER_LINK \n"

# Retrieve the credential offer
CREDENTIAL_OFFER=$(curl -k -s $CREDENTIAL_OFFER_LINK \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $USER_ACCESS_TOKEN")

# Display the credential offer
echo -e "Credential Offer: $CREDENTIAL_OFFER \n"

# Parse the pre-authorized_code
PRE_AUTHORIZED_CODE=$(echo $CREDENTIAL_OFFER | jq -r '."grants"."urn:ietf:params:oauth:grant-type:pre-authorized_code"."pre-authorized_code"')

# Stop if PRE_AUTHORIZED_CODE is not retrieved
if [ -z "$PRE_AUTHORIZED_CODE" ]; then
    echo "Failed to retrieve PRE_AUTHORIZED_CODE"
    exit 1
fi

echo -e "Pre-Authorized Code: $PRE_AUTHORIZED_CODE \n"

# Retrieve the c_nonce from the keycloak nonce endpoint
C_NONCE=$(curl -k -s -X POST $KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/nonce | jq -r '.c_nonce')

echo -e "C_NONCE: $C_NONCE \n"

# Obtain the credential
# See: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#name-token-request
CREDENTIAL_BEARER_TOKEN=$(curl -k -s $KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code' \
    -d "pre-authorized_code=$PRE_AUTHORIZED_CODE" \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=$CLIENT_SECRET")

# Stop if CREDENTIAL_BEARER_TOKEN is not retrieved
if [ -z "$CREDENTIAL_BEARER_TOKEN" ]; then
    echo "Failed to retrieve CREDENTIAL_BEARER_TOKEN"
    exit 1
fi

echo -e "Credential Bearer Token: $CREDENTIAL_BEARER_TOKEN \n"

CREDENTIAL_ACCESS_TOKEN=$(echo $CREDENTIAL_BEARER_TOKEN | jq -r '.access_token')

# Stop if CREDENTIAL_ACCESS_TOKEN is not retrieved
if [ -z "$CREDENTIAL_ACCESS_TOKEN" ]; then
    echo "Failed to retrieve CREDENTIAL_ACCESS_TOKEN"
    exit 1
fi

echo -e "Credential Access Token: $CREDENTIAL_ACCESS_TOKEN \n"

# Generate key proof
. "$(dirname "$0")/../utils/generate_key_proof.sh"

# Prepare request payload
REQ_BODY=$(jq \
  --arg credential_identifier "$CREDENTIAL_TYPE" \
  --arg proof_jwt "$USER_KEY_PROOF" \
  '.credential_identifier = $credential_identifier | .proofs.jwt = [$proof_jwt]' \
  "config/keys/credential_request_body.json")

echo -e "REQ_BODY: $REQ_BODY \n"

# Obtain the credential
CREDENTIAL=$(curl -k -s $KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/oid4vc/credential \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $CREDENTIAL_ACCESS_TOKEN" \
    -d "$REQ_BODY")

# Stop if CREDENTIAL is not retrieved
if [ -z "$CREDENTIAL" ]; then
    echo "Failed to retrieve CREDENTIAL"
    exit 1
fi

echo -e "Credential: $CREDENTIAL \n"

if echo "$CREDENTIAL" | jq -e '.error' > /dev/null; then
    echo "❌ Error retrieving credential: $(echo "$CREDENTIAL" | jq -r '.error_description // .error')"
    exit 1
fi

echo "✅ Successfully retrieved $CREDENTIAL_TYPE credential!"
