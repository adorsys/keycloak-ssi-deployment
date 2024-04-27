#!/bin/bash

# Navigate to the keycloak client tools directory
#### If you are running from you ide
# export KC_CLIENT_TOOLS=$DEV_DIR/keycloak/quarkus/dist/target/keycloak-client-tools
####
# If you unpacked kc
export KC_CLIENT_TOOLS=$TOOLS_DIR/keycloak-999.0.0-SNAPSHOT

# Get admin token
# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin
echo "Retrieving admin credentials..."
$KC_CLIENT_TOOLS/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user $KEYCLOAK_ADMIN --password $KEYCLOAK_ADMIN_PASSWORD

# Read the direct access property of the account console
echo "Reading direct access property of the account-console client..."
$KC_CLIENT_TOOLS/bin/kcadm.sh get clients -q clientId=account-console --fields 'id,directAccessGrantsEnabled'

# Store property ACC_CLIENT_ID in an environment variable
export ACC_CLIENT_ID=$($KC_CLIENT_TOOLS/bin/kcadm.sh get clients -q clientId=account-console --fields id | jq -r '.[0].id')
echo "Stored Account Console Client ID: $ACC_CLIENT_ID"

# Enable direct grant on the account-console client
echo "Enabling direct grant on the account-console client..."
$KC_CLIENT_TOOLS/bin/kcadm.sh update clients/$ACC_CLIENT_ID -r master -s directAccessGrantsEnabled=true -o --fields 'id,directAccessGrantsEnabled'

# Create a user named Francis
echo "Creating user Francis..."
$KC_CLIENT_TOOLS/bin/kcadm.sh create users -r master -s username=francis -s firstName=Francis -s lastName=Pouatcha -s email=fpo@mail.de -s enabled=true

# Set password for Francis
echo "Setting password for user Francis..."
# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
export FRANCIS_NAME=francis
export FRANCIS_PASSWORD=francis
$KC_CLIENT_TOOLS/bin/kcadm.sh set-password -r master --username $FRANCIS_NAME --new-password $FRANCIS_PASSWORD

echo "Script execution completed."
