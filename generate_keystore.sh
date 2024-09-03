#!/bin/bash

# Source common env variables
. load_env.sh

# Generate a keypairs into a PKCS12 keystore using java. 
# We prefer an external file, as content will be shared among servers.

echo "Generating $KEYCLOAK_KEYSTORE_FILE..."

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
