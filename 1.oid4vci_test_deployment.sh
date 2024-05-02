#!/bin/bash

# Ensure keycloak with oid4vc-vci profile is running

# We work on following assumptions
export DEV_DIR=~/dev
export TOOLS_DIR=~/tools


# Checkout this project
cd $TOOLS_DIR && git clone https://github.com/adorsys/keycloak-ssi-deployment.git

# Navigate to the keycloak client tools directory
#### If you are running from you ide
# export KC_CLIENT_TOOLS=$DEV_DIR/keycloak/quarkus/dist/target/keycloak-client-tools
####
# If you unpacked kc
export KC_CLIENT_TOOLS=$TOOLS_DIR/keycloak-999.0.0-SNAPSHOT


# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin
$KC_CLIENT_TOOLS/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user $KEYCLOAK_ADMIN --password $KEYCLOAK_ADMIN_PASSWORD

# Create client for oid4vci
echo "Creating OID4VCI client..."
$KC_CLIENT_TOOLS/bin/kcadm.sh create clients -o -f - < $TOOLS_DIR/keycloak-ssi-deployment/client-oid4vc.json
$KC_CLIENT_TOOLS/bin/kcadm.sh create clients -o -f - < $TOOLS_DIR/keycloak-ssi-deployment/client-oid4vc.json || { echo 'Client creation failed' ; exit 1; }

# Manually copy the content of your PEM file into issuer-key.json if you generate a new PEM file
# Register the EC-key with Keycloak
echo "Registering issuer key..."
$KC_CLIENT_TOOLS/bin/kcadm.sh create components -r master -o -f - < $TOOLS_DIR/keycloak-ssi-deployment/issuer_key.json
$KC_CLIENT_TOOLS/bin/kcadm.sh create components -r master -o -f - < $TOOLS_DIR/keycloak-ssi-deployment/issuer_key.json || { echo 'Key registration failed' ; exit 1; }

# Export keyid into an environment variable
export ES256_KID=$($KC_CLIENT_TOOLS/bin/kcadm.sh get keys --fields 'active(ES256)' | jq -r '.active.ES256')
echo "ES256 Key ID: $ES256_KID"

# Write keyid into a copy of the signing_service.json
echo "Configuring signing service with Key ID..."
jq --arg kid "$ES256_KID" '.config.keyId[] = $kid' $TOOLS_DIR/keycloak-ssi-deployment/signing_service.json > signing_service.json

# Create the signing service component
echo "Creating signing service component..."
$TOOLS_DIR/bin/kcadm.sh create components -r master -o -f - < signing_service.json

# Useful link to check the configuration
echo "Navigate to the following URL to verify the OIDC credential issuer setup:"
echo "http://localhost:8080/realms/master/.well-known/openid-credential-issuer"

# Read all realm attributes
# echo "Reading all realm attributes..."
# $TOOLS_DIR/bin/kcadm.sh get realms -r master --fields 'attributes(*)'

# Add realm attribute issuerDid
echo "Updating realm attributes for issuerDid..."
$TOOLS_DIR/bin/kcadm.sh update realms/master -s attributes.issuerDid=did:web:adorsys.org

echo "Deployment script completed."
