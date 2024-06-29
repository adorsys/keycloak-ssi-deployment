#!/bin/bash

# Source common env variables
. .env

# Retrieve the bearer token
response=$(curl -s -o $TARGET_DIR/response.json -w "%{http_code}" -X POST $KEYCLOAK_ADMIN_ADDR/realms/master/protocol/openid-connect/token \
    -d "client_id=account-console" \
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
CREDENTIAL_OFFER_LINK=$(curl -s $KEYCLOAK_ADMIN_ADDR/realms/master/protocol/oid4vc/credential-offer-uri?credential_configuration_id=test-credential \
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
CREDENTIAL_OFFER=$(curl -s $CREDENTIAL_OFFER_LINK \
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

# Obtain the credential
# See: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#name-token-request
CREDENTIAL_BEARER_TOKEN=$(curl -s $KEYCLOAK_ADMIN_ADDR/realms/master/protocol/openid-connect/token \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code' \
    -d "pre-authorized_code=$PRE_AUTHORIZED_CODE" \
    -d "client_id=oid4vci-client")

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

# Obtain the credential
CREDENTIAL=$(curl -s $KEYCLOAK_ADMIN_ADDR/realms/master/protocol/oid4vc/credential \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $CREDENTIAL_ACCESS_TOKEN" \
    -d '{"format": "vc+sd-jwt", "credential_identifier": "test-credential"}')


# Stop if CREDENTIAL is not retrieved
if [ -z "$CREDENTIAL" ]; then
    echo "Failed to retrieve CREDENTIAL"
    exit 1
fi

echo -e "Credential: $CREDENTIAL \n"
