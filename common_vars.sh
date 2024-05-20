#!/bin/bash

# This scrip is being executed in the working directory
WORK_DIR=$(pwd)
TARGET_DIR=$WORK_DIR/target

# Dev and tools dir
TOOLS_DIR=$TARGET_DIR/tools

# Dev dir where to clone keycloak
KC_OID4VCI=keycloak-oid4vci

# Ensure all sensitive data like passwords and keys are passed through environment variables or secure stores.
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

KEYCLOAK_KEYSTORE_FILE=$TARGET_DIR/oid4vci_signing_key.pkcs12
KEYCLOAK_KEYSTORE_TYPE=PKCS12
KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS=ecdsa_key
# Waring for java implementation of pkcs12, keystore password and key password must be the same.
# https://support.oracle.com/knowledge/Middleware/2364856_1.html
KEYCLOAK_KEYSTORE_PASSWORD=ecdsa_key_password
KEYCLOAK_KEYSTORE_ECDSA_KEY_PASSWORD=ecdsa_key_password

# Navigate to the keycloak client tools directory
#### If you are running from you ide
# KC_INSTALL_DIR=$DEV_DIR/keycloak/quarkus/dist/target/keycloak-client-tools
####
# if you unpacked: Keycloak installation directory
KC_INSTALL_DIR=$TOOLS_DIR/keycloak-999.0.0-SNAPSHOT

# User credentials
USER_FRANCIS_NAME=francis
USER_FRANCIS_PASSWORD=francis


