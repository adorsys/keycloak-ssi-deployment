#!/bin/bash

# Source common env variables
. load_env.sh

# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KEYCLOAK_ADMIN --password $KEYCLOAK_ADMIN_PASSWORD

# Read the direct access property of the openid4vc-rest-api client
echo "Reading direct access property of the openid4vc-rest-api client..."
$KC_INSTALL_DIR/bin/kcadm.sh get clients -q clientId=openid4vc-rest-api --fields 'id,directAccessGrantsEnabled'

# Store property ACC_CLIENT_ID in an environment variable
export ACC_CLIENT_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -q clientId=openid4vc-rest-api --fields id | jq -r '.[0].id')
echo "Stored openid4vc-rest-api Client ID: $ACC_CLIENT_ID"

# Enable direct grant on the openid4vc-rest-api client
echo "Enabling direct grant on the openid4vc-rest-api client..."
$KC_INSTALL_DIR/bin/kcadm.sh update clients/$ACC_CLIENT_ID -r master -s directAccessGrantsEnabled=true -o --fields 'id,directAccessGrantsEnabled'

# Create a user named Francis
echo "Creating user Francis..."
$KC_INSTALL_DIR/bin/kcadm.sh create users -r master -s username=francis -s firstName=Francis -s lastName=Pouatcha -s email=fpo@mail.de -s enabled=true

# Set password for Francis
echo "Setting password for user Francis..."
$KC_INSTALL_DIR/bin/kcadm.sh set-password -r master --username $USER_FRANCIS_NAME --new-password $USER_FRANCIS_PASSWORD

# Prepare user key proof header if not existent
if [ ! -f "$TARGET_DIR/user_key_proof_header.json" ]; then
  echo "Generating keypar for user ..."
  . ./generate_user_key.sh
fi

echo "Script execution completed."
