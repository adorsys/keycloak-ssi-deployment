#!/bin/bash

# Source common env variables
. load_env.sh

# Ensure keycloak with oid4vc-vci profile is running
# Function to get the Keycloak PID based on the OS
get_keycloak_pid() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo $(ps aux | grep -i '[q]uarkus' | awk '{print $2}')
  else
    # Linux
    echo $(ps aux | grep -i '[k]eycloak' | awk '{print $2}')
  fi
}

# Get the Keycloak PID
keycloak_pid=$(get_keycloak_pid)

# Check if Keycloak is running
if [ -z "$keycloak_pid" ]; then
    echo "Keycloak not running. Start Keycloak using 0.start-kc-oid4vci first..."
    exit 1
fi

echo "Keycloak is running with PID: $keycloak_pid"


# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD

# Create new realm
$KC_INSTALL_DIR/bin/kcadm.sh create realms -s realm=$KEYCLOAK_REALM -s enabled=true

# Collect the 4 active keys to be disabled.
RSA_OAEP_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM --fields 'active(RSA-OAEP)' | jq -r '.active."RSA-OAEP"')
RSA_OAEP_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
echo "Generated RSA-OAEP key will be disabled... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"

# HS512_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(HS512)' | jq -r '.active.HS512')
# HS512_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$HS512_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
# echo "Generated HS512 key will be disbled... KID=$HS512_KID PROV_ID=$HS512_PROV_ID"

RS256_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM --fields 'active(RS256)' | jq -r '.active.RS256')
RS256_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
echo "Generated RS256 key will be disabled... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"

# AES_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(AES)' | jq -r '.active.AES')
# AES_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$AES_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
# echo "Generated AES key will be disbled... KID=$AES_KID PROV_ID=$AES_PROV_ID"

# Keystore must have been set up at build time.
# Find relative path for the following config to remain valid
# should the database be reconnected to a dockerized Keycloak.
cd $KC_INSTALL_DIR
KEYCLOAK_KEYSTORE_FILE="../../$(basename $KEYCLOAK_KEYSTORE_FILE)"

# Add concret info and passwords to key provider
echo "Configuring ecdsa key provider..."
ECDSA_KEY_PROVIDER=$(cat $WORK_DIR/issuer_key_ecdsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]')

echo "Configuring rsa signing key provider..."
RSA_KEY_PROVIDER=$(cat $WORK_DIR/issuer_key_rsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]')

echo "Configuring rsa enc key provider..."
RSA_ENC_KEY_PROVIDER=$(cat $WORK_DIR/encryption_key_rsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]')

# echo "Configuring hmac signature key provider..."
# HMAC_SIG_KEY_ID=$(uuidgen)
# less $WORK_DIR/signature_key_hmac.json | \
#   jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
#   --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
#   --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
#   --arg keyAlias "$KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS" \
#   --arg kid "$HMAC_SIG_KEY_ID" \
#   --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
#   '.config.keystore = [$keystore] | 
#    .config.keystorePassword = [$keystorePassword] |
#    .config.keystoreType = [$keystoreType] | 
#    .config.keyAlias = [$keyAlias] | 
#    .config.kid = [$kid] | 
#    .config.keyPassword = [$keyPassword]' \
#   > $TARGET_DIR/signature_key_hmac-tmp.json 

# echo "Configuring aes enc key provider..."
# AES_ENC_KEY_ID=$(uuidgen)
# less $WORK_DIR/encryption_key_aes.json | \
#   jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
#   --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
#   --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
#   --arg keyAlias "$KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS" \
#   --arg kid "$AES_ENC_KEY_ID" \
#   --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
#   '.config.keystore = [$keystore] | 
#    .config.keystorePassword = [$keystorePassword] |
#    .config.keystoreType = [$keystoreType] | 
#    .config.keyAlias = [$keyAlias] | 
#    .config.kid = [$kid] | 
#    .config.keyPassword = [$keyPassword]' \
#   > $TARGET_DIR/encryption_key_aes-tmp.json 

# Register the EC-key with Keycloak
echo "Registering issuer key ecdsa..."
echo "$ECDSA_KEY_PROVIDER" | $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - || { echo 'ECDSA Issuer Key registration failed' ; exit 1; }

echo "Registering issuer key rsa..."
echo "$RSA_KEY_PROVIDER" | $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - || { echo 'RSA Issuer Key registration failed' ; exit 1; }

echo "Registering encryption key rsa..."
echo "$RSA_ENC_KEY_PROVIDER" | $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - || { echo 'RSA Encryption Key registration failed' ; exit 1; }

# echo "Registering signature key hmac..."
# $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - < $TARGET_DIR/signature_key_hmac-tmp.json || { echo 'Hmac Signature Key registration failed' ; exit 1; }
# echo "Registering issuer key ecdsa..."
# $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - < $TARGET_DIR/encryption_key_aes-tmp.json || { echo 'AES Encryption Key registration failed' ; exit 1; }

# Disable generated keys
echo "Deactivating generated RSA-OAEP... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"
$KC_INSTALL_DIR/bin/kcadm.sh update components/$RSA_OAEP_PROV_ID -r $KEYCLOAK_REALM -s 'config.active=["false"]' || { echo 'Updating RSA_OAEP provider failed' ; exit 1; }
$KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)'

# echo "Deactivating generated HS512 key... KID=$HS512_KID PROV_ID=$HS512_PROV_ID"
# $KC_INSTALL_DIR/bin/kcadm.sh update components/$HS512_PROV_ID -s 'config.active=["false"]' || { echo 'Updating HS512 provider failed' ; exit 1; }
# $KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$HS512_KID" '.keys[] | select(.kid == $kid)'

echo "Deactivating generated RS256 key... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"
$KC_INSTALL_DIR/bin/kcadm.sh update components/$RS256_PROV_ID -r $KEYCLOAK_REALM -s 'config.active=["false"]' || { echo 'Updating RS256 provider failed' ; exit 1; }
$KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)'

# echo "Deactivating generated AES key will... KID=$AES_KID PROV_ID=$AES_PROV_ID"
# $KC_INSTALL_DIR/bin/kcadm.sh update components/$AES_PROV_ID -s 'config.active=["false"]' || { echo 'Updating AES provider failed' ; exit 1; }
# $KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$AES_KID" '.keys[] | select(.kid == $kid)'

# Create the signing service component for SteuerberaterCredential
echo "Creating signing service component for SteuerberaterCredential..."
SIGNING_SERVICE_TEST_CRED=$(cat $WORK_DIR/signing_service-SteuerberaterCredential.json)
echo "$SIGNING_SERVICE_TEST_CRED" | $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - || { echo 'Could not create signing service component for SteuerberaterCredential' ; exit 1; }

echo "Creating signing service component for IdentityCredential..."
SIGNING_SERVICE_IDENTITYCRED=$(cat $WORK_DIR/signing_service-IdentityCredential.json)
echo "$SIGNING_SERVICE_IDENTITYCRED" | $KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - || { echo 'Could not create signing service component for IdentityCredential' ; exit 1; }

# Create client for oid4vci
echo "Creating OID4VCI client..."
OID4VCI_CLIENT=$(cat $WORK_DIR/client-oid4vc.json)
echo "$OID4VCI_CLIENT" | $KC_INSTALL_DIR/bin/kcadm.sh create clients -r $KEYCLOAK_REALM -o -f - || { echo 'OID4VCIClient creation failed' ; exit 1; }

# Passing openid4vc-rest-api.json to jq to fill it with the secret before exporting config to keycloak
CONFIG=$(cat "$WORK_DIR/openid4vc-rest-api.json" | jq \
  --arg CLIENT_SECRET "$CLIENT_SECRET" \
  --arg ISSUER_BACKEND_URL "$ISSUER_BACKEND_URL" \
  --arg ISSUER_FRONTEND_URL "$ISSUER_FRONTEND_URL" \
  '.secret = $CLIENT_SECRET | 
   .redirectUris = [$ISSUER_BACKEND_URL + "/*", "http://back.localhost.com/*"] | 
   .webOrigins = [$ISSUER_BACKEND_URL] | 
   .attributes["post.logout.redirect.uris"] =($ISSUER_FRONTEND_URL + "/*##" + $ISSUER_FRONTEND_URL + "##http://localhost:5173##http://front.localhost.com")'
)

# Create client for openid4vc-rest-api
echo "Creating OPENID4VC-REST-API client..."
echo "$CONFIG" | $KC_INSTALL_DIR/bin/kcadm.sh create clients -r $KEYCLOAK_REALM -o -f - || { echo 'OPENID4VC-REST-API client creation failed' ; exit 1; }

# Clear the CONFIG variable
unset CONFIG

# Add realm attribute issuerDid
echo "Updating realm attributes for issuerDid..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/$KEYCLOAK_REALM -s attributes.issuerDid=$ISSUER_DID || { echo 'Could not set issuer did' ; exit 1; }

# Increase lifespan of preauth code
echo "Updating realm attributes for preAuthorizedCodeLifespanS..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/$KEYCLOAK_REALM -s attributes.preAuthorizedCodeLifespanS=120  || { echo 'Could not set preAuthorizedCodeLifespanS' ; exit 1; }


# Check server status and oid4vc-vci feature
response=$(curl -k -s $KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/.well-known/openid-credential-issuer)

if ! jq -e '."credential_configurations_supported"."SteuerberaterCredential"' <<< "$response" > /dev/null; then
    echo "Server started but error occurred. 'SteuerberaterCredential' not found in OID4VCI configuration."
    exit 1  # Exit with an error code
fi

if ! jq -e '."credential_configurations_supported"."IdentityCredential"' <<< "$response" > /dev/null; then
    echo "Server started but error occurred. 'IdentityCredential' not found in OID4VCI configuration."
    exit 1  # Exit with an error code
fi

# Server is up and OID4VCI feature with 'SteuerberaterCredential' seems installed
echo "Keycloak server is running with OID4VCI feature and credentials 'SteuerberaterCredential, IdentityCredential' configured."

echo "Deployment script completed."
