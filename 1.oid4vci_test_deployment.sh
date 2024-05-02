#!/bin/bash

# Source common env variables
. ./common_vars.sh

# Ensure keycloak with oid4vc-vci profile is running
keycloak_pid=$(ps aux | grep -i '[k]eycloak' | awk '{print $2}')
if [ ! -n "$keycloak_pid" ]; then
    echo "Keycloak not running. Start keycloak using 0.start-kc-oid4vci first..."
    exit 1
fi


# Checkout this project. Shall have been done, we wouldn't see this file
# cd $TOOLS_DIR && git clone https://github.com/adorsys/keycloak-ssi-deployment.git

# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user $KEYCLOAK_ADMIN --password $KEYCLOAK_ADMIN_PASSWORD

# Create client for oid4vci
echo "Creating OID4VCI client..."
$KC_INSTALL_DIR/bin/kcadm.sh create clients -o -f - < $WORK_DIR/client-oid4vc.json || { echo 'Client creation failed' ; exit 1; }

# Manually copy the content of your PEM file into issuer-key.json if you generate a new PEM file
# Register the EC-key with Keycloak
echo "Registering issuer key..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $WORK_DIR/issuer_key.json || { echo 'Key registration failed' ; exit 1; }

# Export keyid into an environment variable
export ES256_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(ES256)' | jq -r '.active.ES256')
echo "ES256 Key ID: $ES256_KID"

# Write keyid into a copy of the signing_service.json
echo "Configuring signing service with Key ID..."
less $WORK_DIR/signing_service.json | jq --arg kid "$ES256_KID" '.config.keyId = [$kid]'  > $TARGET_DIR/signing_service-tmp.json

# Create the signing service component
echo "Creating signing service component..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/signing_service-tmp.json  || { echo 'Could not create signing service' ; exit 1; }

# Useful link to check the configuration
# Ensure keycloak with oid4vc-vci profile is running
keycloak_pid=$(ps aux | grep -i '[k]eycloak' | awk '{print $2}')
if [ ! -n "$keycloak_pid" ]; then
    echo "Keycloak not running. Start keycloak using 0.start-kc-oid4vci first..."
    exit 1  # Exit with an error code
fi

# Read all realm attributes
# echo "Reading all realm attributes..."
# $TOOLS_DIR/bin/kcadm.sh get realms -r master --fields 'attributes(*)'

# Add realm attribute issuerDid
echo "Updating realm attributes for issuerDid..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/master -s attributes.issuerDid=did:web:adorsys.org  || { echo 'Could not set issuer did' ; exit 1; }

# Check server status and oid4vc-vci feature
response=$(curl -s http://localhost:8080/realms/master/.well-known/openid-credential-issuer)

if ! jq -e '."credential_configurations_supported"."test-credential"' <<< "$response" > /dev/null; then
    echo "Server started but error occurred. 'test-credential' not found in OID4VCI configuration."
    exit 1  # Exit with an error code
fi

# Server is up and OID4VCI feature with 'test-credential' seems installed
echo "Keycloak server is running with OID4VCI feature and 'test-credential' configured."

echo "Deployment script completed."
