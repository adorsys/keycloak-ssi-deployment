#!/bin/bash

# Source common env variables
. ./common_vars.sh

# Ensure keycloak with oid4vc-vci profile is running
keycloak_pid=$(ps aux | grep -i '[k]eycloak' | awk '{print $2}')
if [ ! -n "$keycloak_pid" ]; then
    echo "Keycloak not running. Start keycloak using 0.start-kc-oid4vci first..."
    exit 1
fi

# Get admin token using environment variables for credentials
echo "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user $KEYCLOAK_ADMIN --password $KEYCLOAK_ADMIN_PASSWORD

# Collect the 4 active keys to be disabled.
RSA_OAEP_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(RSA-OAEP)' | jq -r '.active."RSA-OAEP"')
RSA_OAEP_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
echo "Generated RSA-OAEP key will be disbled... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"

# HS512_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(HS512)' | jq -r '.active.HS512')
# HS512_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$HS512_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
# echo "Generated HS512 key will be disbled... KID=$HS512_KID PROV_ID=$HS512_PROV_ID"

RS256_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(RS256)' | jq -r '.active.RS256')
RS256_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
echo "Generated RS256 key will be disbled... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"

# AES_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys --fields 'active(AES)' | jq -r '.active.AES')
# AES_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$AES_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
# echo "Generated AES key will be disbled... KID=$AES_KID PROV_ID=$AES_PROV_ID"

# Delete keystore if one exists
# change into keycloak directory & build keycloak
if [ -f "$KEYCLOAK_KEYSTORE_FILE" ]; then
    echo "File $KEYCLOAK_KEYSTORE_FILE exists, will be deleted..."
    rm "$KEYCLOAK_KEYSTORE_FILE"
fi

# Generate a keypairs into a PKCS12 keystore using java. We prefer an external file, as content will be shared among servers.
keytool \
  -genkeypair \
  -keyalg EC \
  -keysize 256 \
  -keystore $KEYCLOAK_KEYSTORE_FILE \
  -storepass $KEYCLOAK_KEYSTORE_PASSWORD \
  -alias $KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS \
  -keypass $KEYCLOAK_KEYSTORE_PASSWORD \
  -storetype $KEYCLOAK_KEYSTORE_TYPE \
  -dname "CN=ECDSA Signing Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=Cameroon"

keytool \
  -genkeypair \
  -keyalg RSA \
  -keysize 3072 \
  -keystore $KEYCLOAK_KEYSTORE_FILE \
  -storepass $KEYCLOAK_KEYSTORE_PASSWORD \
  -alias $KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS \
  -keypass $KEYCLOAK_KEYSTORE_PASSWORD \
  -storetype $KEYCLOAK_KEYSTORE_TYPE \
  -dname "CN=RSA Signing Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=Cameroon" 

keytool \
  -genkeypair \
  -keyalg RSA \
  -keysize 3072 \
  -keystore $KEYCLOAK_KEYSTORE_FILE \
  -storepass $KEYCLOAK_KEYSTORE_PASSWORD \
  -alias $KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS \
  -keypass $KEYCLOAK_KEYSTORE_PASSWORD \
  -storetype $KEYCLOAK_KEYSTORE_TYPE \
  -dname "CN=RSA Encryption Key, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=Cameroon" 

# keytool \
#   -genseckey \
#   -keyalg HmacSHA512 \
#   -keysize 512 \
#   -keystore $KEYCLOAK_KEYSTORE_FILE \
#   -storepass $KEYCLOAK_KEYSTORE_PASSWORD \
#   -alias $KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS \
#   -keypass $KEYCLOAK_KEYSTORE_PASSWORD \
#   -storetype $KEYCLOAK_KEYSTORE_TYPE

# keytool \
#   -genseckey \
#   -keyalg AES \
#   -keysize 256 \
#   -keystore $KEYCLOAK_KEYSTORE_FILE \
#   -storepass $KEYCLOAK_KEYSTORE_PASSWORD \
#   -alias $KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS \
#   -keypass $KEYCLOAK_KEYSTORE_PASSWORD \
#   -storetype $KEYCLOAK_KEYSTORE_TYPE 

# Add concret info and passwords to key provider
echo "Configuring ecdsa key provider..."
less $WORK_DIR/issuer_key_ecdsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]' \
  > $TARGET_DIR/issuer_key_ecdsa-tmp.json 

echo "Configuring rsa signing key provider..."
less $WORK_DIR/issuer_key_rsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]' \
  > $TARGET_DIR/issuer_key_rsa-tmp.json 

echo "Configuring rsa enc key provider..."
less $WORK_DIR/encryption_key_rsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]' \
  > $TARGET_DIR/encryption_key_rsa-tmp.json 

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
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/issuer_key_ecdsa-tmp.json || { echo 'ECDSA Issuer Key registration failed' ; exit 1; }
echo "Registering issuer key rsa..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/issuer_key_rsa-tmp.json || { echo 'RSA Issuer Key registration failed' ; exit 1; }
echo "Registering encryption key rsa..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/encryption_key_rsa-tmp.json || { echo 'RSA Encryption Key registration failed' ; exit 1; }
# echo "Registering signature key hmac..."
# $KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/signature_key_hmac-tmp.json || { echo 'Hmac Signature Key registration failed' ; exit 1; }
# echo "Registering issuer key ecdsa..."
# $KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $TARGET_DIR/encryption_key_aes-tmp.json || { echo 'AES Encryption Key registration failed' ; exit 1; }

# Disable generated keys
echo "Deactivating generated RSA-OAEP... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"
$KC_INSTALL_DIR/bin/kcadm.sh update components/$RSA_OAEP_PROV_ID -s 'config.active=["false"]' || { echo 'Updating RSA_OAEP provider failed' ; exit 1; }
$KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)'

# echo "Deactivating generated HS512 key... KID=$HS512_KID PROV_ID=$HS512_PROV_ID"
# $KC_INSTALL_DIR/bin/kcadm.sh update components/$HS512_PROV_ID -s 'config.active=["false"]' || { echo 'Updating HS512 provider failed' ; exit 1; }
# $KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$HS512_KID" '.keys[] | select(.kid == $kid)'

echo "Deactivating generated RS256 key... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"
$KC_INSTALL_DIR/bin/kcadm.sh update components/$RS256_PROV_ID -s 'config.active=["false"]' || { echo 'Updating RS256 provider failed' ; exit 1; }
$KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)'

# echo "Deactivating generated AES key will... KID=$AES_KID PROV_ID=$AES_PROV_ID"
# $KC_INSTALL_DIR/bin/kcadm.sh update components/$AES_PROV_ID -s 'config.active=["false"]' || { echo 'Updating AES provider failed' ; exit 1; }
# $KC_INSTALL_DIR/bin/kcadm.sh get keys | jq --arg kid "$AES_KID" '.keys[] | select(.kid == $kid)'

# Create the signing service component for test-credential
echo "Creating signing service component for test-credential..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $WORK_DIR/signing_service-test-credential.json  || { echo 'Could not create signing service component for test-credential' ; exit 1; }

echo "Creating signing service component for IdentityCredential..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r master -o -f - < $WORK_DIR/signing_service-IdentityCredential.json  || { echo 'Could not create signing service component for IdentityCredential' ; exit 1; }

# Create client for oid4vci
echo "Creating OID4VCI client..."
$KC_INSTALL_DIR/bin/kcadm.sh create clients -o -f - < $WORK_DIR/client-oid4vc.json || { echo 'OID4VCIClient creation failed' ; exit 1; }

# Add realm attribute issuerDid
echo "Updating realm attributes for issuerDid..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/master -s attributes.issuerDid=$ISSUER_DID || { echo 'Could not set issuer did' ; exit 1; }

# Increase lifespan of preauth code
echo "Updating realm attributes for preAuthorizedCodeLifespanS..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/master -s attributes.preAuthorizedCodeLifespanS=120  || { echo 'Could not set preAuthorizedCodeLifespanS' ; exit 1; }


# Check server status and oid4vc-vci feature
response=$(curl -s http://localhost:8080/realms/master/.well-known/openid-credential-issuer)

if ! jq -e '."credential_configurations_supported"."test-credential"' <<< "$response" > /dev/null; then
    echo "Server started but error occurred. 'test-credential' not found in OID4VCI configuration."
    exit 1  # Exit with an error code
fi

if ! jq -e '."credential_configurations_supported"."IdentityCredential"' <<< "$response" > /dev/null; then
    echo "Server started but error occurred. 'IdentityCredential' not found in OID4VCI configuration."
    exit 1  # Exit with an error code
fi

# Server is up and OID4VCI feature with 'test-credential' seems installed
echo "Keycloak server is running with OID4VCI feature and credentials 'test-credential, IdentityCredential' configured."

echo "Deployment script completed."
