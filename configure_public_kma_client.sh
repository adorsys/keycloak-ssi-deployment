#!/bin/bash

# Script to configure a public client for KMA credential issuance in Keycloak
# This script creates a public client in a different realm that can issue KMA credentials

# Source common env variables
. load_env.sh

# Configuration variables
CLIENT_CONFIG_FILE="public-kma-client.json"
TARGET_REALM="${TARGET_REALM:-oid4vc-vci}"  # Default realm, can be overridden
CLIENT_ID="public-kma-client"

echo "=========================================="
echo "Configuring Public KMA Client in Keycloak"
echo "=========================================="
echo "Target Realm: $TARGET_REALM"
echo "Client ID: $CLIENT_ID"
echo ""

# Check if client config file exists
if [ ! -f "$CLIENT_CONFIG_FILE" ]; then
    echo "Error: Client configuration file '$CLIENT_CONFIG_FILE' not found!"
    exit 1
fi

# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD

# Check if target realm exists
echo "Checking if target realm '$TARGET_REALM' exists..."
REALM_EXISTS=$($KC_INSTALL_DIR/bin/kcadm.sh get realms/$TARGET_REALM 2>/dev/null | jq -r '.realm // empty')
if [ -z "$REALM_EXISTS" ]; then
    echo "Error: Target realm '$TARGET_REALM' does not exist!"
    echo "Available realms:"
    $KC_INSTALL_DIR/bin/kcadm.sh get realms --fields realm | jq -r '.[].realm'
    exit 1
fi

# Check if client already exists
echo "Checking if client '$CLIENT_ID' already exists in realm '$TARGET_REALM'..."
EXISTING_CLIENT=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -r $TARGET_REALM -q clientId=$CLIENT_ID --fields id 2>/dev/null | jq -r '.[0].id // empty')

if [ -n "$EXISTING_CLIENT" ]; then
    echo "Client '$CLIENT_ID' already exists with ID: $EXISTING_CLIENT"
    echo "Updating existing client..."
    
    # Update the existing client
    $KC_INSTALL_DIR/bin/kcadm.sh update clients/$EXISTING_CLIENT -r $TARGET_REALM -f $CLIENT_CONFIG_FILE
    if [ $? -eq 0 ]; then
        echo "✅ Client updated successfully!"
    else
        echo "❌ Failed to update client!"
        exit 1
    fi
else
    echo "Creating new client '$CLIENT_ID' in realm '$TARGET_REALM'..."
    
    # Create the new client
    $KC_INSTALL_DIR/bin/kcadm.sh create clients -r $TARGET_REALM -f $CLIENT_CONFIG_FILE
    if [ $? -eq 0 ]; then
        echo "✅ Client created successfully!"
    else
        echo "❌ Failed to create client!"
        exit 1
    fi
fi

# Get the client ID for further configuration
CLIENT_UUID=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -r $TARGET_REALM -q clientId=$CLIENT_ID --fields id | jq -r '.[0].id')
echo "Client UUID: $CLIENT_UUID"

# Verify client configuration
echo ""
echo "Verifying client configuration..."
CLIENT_INFO=$($KC_INSTALL_DIR/bin/kcadm.sh get clients/$CLIENT_UUID -r $TARGET_REALM --fields 'clientId,publicClient,enabled,protocol,optionalClientScopes')
echo "Client Information:"
echo "$CLIENT_INFO" | jq '.'

# Check if KMACredential scope is attached
echo ""
echo "Checking attached optional scopes..."
ATTACHED_SCOPES=$($KC_INSTALL_DIR/bin/kcadm.sh get clients/$CLIENT_UUID/optional-client-scopes -r $TARGET_REALM --fields 'name')
KMA_SCOPE_ATTACHED=$(echo "$ATTACHED_SCOPES" | jq -r '.[] | select(.name=="KMACredential") | .name // empty')

if [ -n "$KMA_SCOPE_ATTACHED" ]; then
    echo "✅ KMACredential scope is properly attached"
else
    echo "⚠️  KMACredential scope is not attached. Attempting to attach..."
    
    # Get the KMACredential scope ID
    KMA_SCOPE_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get client-scopes -r $TARGET_REALM -q name=KMACredential --fields id | jq -r '.[0].id')
    
    if [ -n "$KMA_SCOPE_ID" ] && [ "$KMA_SCOPE_ID" != "null" ]; then
        # Attach the scope
        $KC_INSTALL_DIR/bin/kcadm.sh update clients/$CLIENT_UUID/optional-client-scopes/$KMA_SCOPE_ID -r $TARGET_REALM
        if [ $? -eq 0 ]; then
            echo "✅ KMACredential scope attached successfully!"
        else
            echo "❌ Failed to attach KMACredential scope!"
        fi
    else
        echo "❌ KMACredential scope not found in realm '$TARGET_REALM'!"
        echo "Available client scopes:"
        $KC_INSTALL_DIR/bin/kcadm.sh get client-scopes -r $TARGET_REALM --fields name | jq -r '.[].name'
    fi
fi

echo ""
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
echo "✅ Client ID: $CLIENT_ID"
echo "✅ Realm: $TARGET_REALM"
echo "✅ Client UUID: $CLIENT_UUID"
echo "✅ Public Client: true"
echo "✅ Protocol: openid-connect"
echo "✅ OID4VCI Enabled: true"
echo "✅ KMACredential Scope: $([ -n "$KMA_SCOPE_ATTACHED" ] && echo "attached" || echo "not attached")"
echo ""
echo "Client can now be used to issue KMA credentials!"
echo "=========================================="
