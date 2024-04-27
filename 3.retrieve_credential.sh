#!/bin/bash

# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
export FRANCIS_NAME=francis
export FRANCIS_PASSWORD=francis

# Retrieve the bearer token
export USER_ACCESS_TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
    -d "client_id=account-console" \
    -d "username=$FRANCIS_NAME" \
    -d "password=$FRANCIS_PASSWORD" \
    -d "grant_type=password" \
    -d "scope=openid" | jq -r '.access_token')

# Stop if USER_ACCESS_TOKEN is not retrieved
if [ -z "$USER_ACCESS_TOKEN" ]; then
    echo "Failed to retrieve USER_ACCESS_TOKEN"
    exit 1
fi

echo -e "Bearer Token: $USER_ACCESS_TOKEN \n"

# Retrieve link to the credential offer
export CREDENTIAL_OFFER_LINK=$(curl -s http://localhost:8080/realms/master/protocol/oid4vc/credential-offer-uri?credential_configuration_id=test-credential \
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
export CREDENTIAL_OFFER=$(curl -s $CREDENTIAL_OFFER_LINK \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $USER_ACCESS_TOKEN")

# Display the credential offer
echo -e "Credential Offer: $CREDENTIAL_OFFER \n"

# Parse the pre-authorized_code
export PRE_AUTHORIZED_CODE=$(echo $CREDENTIAL_OFFER | jq -r '."grants"."urn:ietf:params:oauth:grant-type:pre-authorized_code"."pre-authorized_code"')

# Stop if PRE_AUTHORIZED_CODE is not retrieved
if [ -z "$PRE_AUTHORIZED_CODE" ]; then
    echo "Failed to retrieve PRE_AUTHORIZED_CODE"
    exit 1
fi

echo -e "Pre-Authorized Code: $PRE_AUTHORIZED_CODE \n"

# Obtain the credential
export CREDENTIAL_BEARER_TOKEN=$(curl -s http://localhost:8080/realms/master/protocol/openid-connect/token \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code' \
    -d "code=$PRE_AUTHORIZED_CODE" \
    -d "client_id=oid4vci-client")

# Stop if CREDENTIAL_BEARER_TOKEN is not retrieved
if [ -z "$CREDENTIAL_BEARER_TOKEN" ]; then
    echo "Failed to retrieve CREDENTIAL_BEARER_TOKEN"
    exit 1
fi

echo -e "Credential Bearer Token: $CREDENTIAL_BEARER_TOKEN \n"

export CREDENTIAL_ACCESS_TOKEN=$(echo $CREDENTIAL_BEARER_TOKEN | jq -r '.access_token')

# Stop if CREDENTIAL_ACCESS_TOKEN is not retrieved
if [ -z "$CREDENTIAL_ACCESS_TOKEN" ]; then
    echo "Failed to retrieve CREDENTIAL_ACCESS_TOKEN"
    exit 1
fi

echo -e "Credential Access Token: $CREDENTIAL_ACCESS_TOKEN \n"

# Obtain the credential
export CREDENTIAL=$(curl -v http://localhost:8080/realms/master/protocol/oid4vc/credential \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $CREDENTIAL_ACCESS_TOKEN" \
    -d '{"format": "sd-jwt_vc", "credential_identifier": "test-credential"}')


# Stop if CREDENTIAL is not retrieved
if [ -z "$CREDENTIAL" ]; then
    echo "Failed to retrieve CREDENTIAL"
    exit 1
fi

echo -e "Credential: $CREDENTIAL \n"
