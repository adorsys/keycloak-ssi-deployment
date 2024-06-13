#!/bin/bash

# This scrip is being executed in the working directory
WORK_DIR=$(pwd)
TARGET_DIR=$WORK_DIR/target

# Dev and tools dir
TOOLS_DIR=$TARGET_DIR/tools

# Dev dir where to clone keycloak
# KC_TARGET_BRANCH=main
KC_TARGET_BRANCH=main
KC_OID4VCI="keycloak_"$KC_TARGET_BRANCH

# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

KEYCLOAK_KEYSTORE_FILE=$TARGET_DIR/kc_keystore.pkcs12
KEYCLOAK_KEYSTORE_TYPE=PKCS12
KEYCLOAK_KEYSTORE_PASSWORD=store_key_password

KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS=ecdsa_key
KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS=rsa_sig_key
KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS=rsa_enc_key
KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS=hmac_sig_key
KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS=aes_enc_key

# Navigate to the keycloak client tools directory
#### If you are running from you ide
# KC_INSTALL_DIR=$DEV_DIR/keycloak/quarkus/dist/target/keycloak-client-tools
####
# if you unpacked: Keycloak installation directory
KC_INSTALL_DIR=$TOOLS_DIR/keycloak-999.0.0-SNAPSHOT

# User credentials
USER_FRANCIS_NAME=francis
USER_FRANCIS_PASSWORD=francis

ISSUER_DID=https://keycloak.solutions.adorsys.com/realms/master


