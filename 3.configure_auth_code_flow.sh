#!/bin/bash

# Source common env variables
. load_env.sh

# Ensure Keycloak is running
echo "Waiting for Keycloak to be available at ${KEYCLOAK_ADMIN_ADDR}..."
until curl -s -k "${KEYCLOAK_ADMIN_ADDR}/health" > /dev/null; do
  sleep 5
done
echo "Keycloak is up!"

# Get admin token
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD

# Ensure user exists
echo "Checking for user francis..."
USER_EXISTS=$($KC_INSTALL_DIR/bin/kcadm.sh get users -r $KEYCLOAK_REALM --fields username | jq -r '.[] | select(.username=="francis") | .username')
if [ "$USER_EXISTS" != "francis" ]; then
  echo "User francis does not exist. Run 2.configure_user_4_account_client.sh first."
  exit 1
fi

# Generate user key proof if not existent
if [ ! -f "$TARGET_DIR/user_key_proof_header.json" ]; then
  echo "Generating key proof for user..."
  . ./generate_user_key.sh
fi

# Function to test credential issuance
test_credential() {
  local CREDENTIAL_ID=$1
  echo ""
  echo "=== Testing issuance of ${CREDENTIAL_ID} ==="

  # Get login token (used for credential offer retrieval)
  echo "Getting login token for francis..."
  LOGIN_TOKEN=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "username=francis" \
    -d "password=${USER_FRANCIS_PASSWORD}" \
    -d "grant_type=password" \
    -d "scope=openid" | jq -r '.access_token')

  if [ -z "$LOGIN_TOKEN" ] || [ "$LOGIN_TOKEN" == "null" ]; then
    echo "Failed to obtain login token."
    exit 1
  fi

  # Retrieve credential offer URI
  echo "Generating credential offer URI for ${CREDENTIAL_ID}..."
  CREDENTIAL_OFFER_LINK=$(curl -k -s "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/credential-offer-uri?credential_configuration_id=${CREDENTIAL_ID}" \
    -H "Authorization: Bearer $LOGIN_TOKEN" | jq -r '"\(.issuer)\(.nonce)"')

  if [ -z "$CREDENTIAL_OFFER_LINK" ] || [ "$CREDENTIAL_OFFER_LINK" == "null" ]; then
    echo "Failed to retrieve CREDENTIAL_OFFER_LINK"
    exit 1
  fi

  echo "Credential offer URI: $CREDENTIAL_OFFER_LINK"

  # Retrieve credential offer
  echo "Retrieving credential offer..."
  CREDENTIAL_OFFER=$(curl -k -s "$CREDENTIAL_OFFER_LINK" -H "Authorization: Bearer $LOGIN_TOKEN")

  if ! echo "$CREDENTIAL_OFFER" | jq -e '.' > /dev/null 2>&1; then
    echo "Invalid credential offer response"
    exit 1
  fi

  # Validate credential configuration
  CONFIG_ID=$(echo "$CREDENTIAL_OFFER" | jq -r '.credential_configuration_ids[] | select(. == "'${CREDENTIAL_ID}'")')
  if [ -z "$CONFIG_ID" ]; then
    echo "Credential configuration ID not found in offer"
    exit 1
  fi

  # Generate issuer state
  ISSUER_STATE="state-$(uuidgen)"

  # Construct authorization URL
  AUTH_REQUEST_URL="${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth?response_type=code&client_id=openid4vc-rest-api&redirect_uri=http://localhost:8080/callback&scope=openid&issuer_state=${ISSUER_STATE}&authorization_details=%7B%22type%22:%22openid_credential%22,%22credential_configuration_id%22:%22${CREDENTIAL_ID}%22%7D"

  # Ask user to manually login and paste auth code
  echo ""
  echo "Please open this URL in your browser, login as 'francis' (password: $USER_FRANCIS_PASSWORD), and copy the code from the redirect URL:"
  echo "$AUTH_REQUEST_URL"
  echo ""
  read -p "Paste the 'code' parameter from the redirect URL: " AUTH_CODE

  if [ -z "$AUTH_CODE" ]; then
    echo "No auth code provided."
    exit 1
  fi

  # Exchange auth code for access token
  echo "Exchanging authorization code for access token..."
  TOKEN_RESPONSE=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
    -d "grant_type=authorization_code" \
    -d "code=${AUTH_CODE}" \
    -d "client_id=openid4vc-rest-api" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "redirect_uri=http://localhost:8080/callback")

  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Failed to obtain access token. Response: $TOKEN_RESPONSE"
    exit 1
  fi
  echo "Access token obtained"

  # Set credential access token for key proof script
  export CREDENTIAL_ACCESS_TOKEN="$ACCESS_TOKEN"
  echo -e "Credential Access Token: $CREDENTIAL_ACCESS_TOKEN \n"

  # Generate proof of possession
  . ./generate_key_proof.sh
  REQ_BODY=$(cat $WORK_DIR/credential_request_body.json | jq --arg credential_identifier "${CREDENTIAL_ID}" --arg proof_jwt "$USER_KEY_PROOF" '.credential_identifier = $credential_identifier | .proof.jwt = $proof_jwt')

  echo "REQ_BODY: " $REQ_BODY

  # Request credential
  echo "Requesting credential..."
  CREDENTIAL=$(curl -s -k -X POST "${KEYCLOAK_ADMIN_ADDR}/realms/${KEYCLOAK_REALM}/protocol/oid4vc/credential" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$REQ_BODY" | jq .)

  if [ -z "$CREDENTIAL" ] || [ "$CREDENTIAL" == "null" ]; then
    echo "Failed to retrieve ${CREDENTIAL_ID}"
    exit 1
  fi

  echo "${CREDENTIAL_ID} successfully issued:"
  echo -e "Credential: $CREDENTIAL \n"
}

# Run tests
test_credential "IdentityCredential"
test_credential "SteuerberaterCredential"

echo "Authorization code flow test completed successfully"
