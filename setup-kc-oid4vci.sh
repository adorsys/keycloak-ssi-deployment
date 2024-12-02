#!/bin/bash

# Source common env variables
. load_env.sh

# Check and create directories
if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR does not exist, creating..."
    mkdir -p "$TARGET_DIR"
    echo "Directory $TARGET_DIR created."
else
    echo "Directory $TARGET_DIR already exists."
fi

if [ ! -d "$TOOLS_DIR" ]; then
    echo "Directory $TOOLS_DIR does not exist, creating..."
    mkdir -p "$TOOLS_DIR"
    echo "Directory $TOOLS_DIR created."
else
    echo "Directory $TOOLS_DIR already exists."
fi

if [ ! -f "$KC_TRUST_STORE" ]; then
    echo "Generating SSl keys..." && \
    source $WORK_DIR/generate-kc-certs.sh
fi

# Download the Keycloak tarball if it doesn't exist
if [ ! -f "$KEYCLOAK_OID4VCI_TARBALL" ]; then
    echo "Downloading Keycloak tarball..."
    curl -L -o "$KEYCLOAK_OID4VCI_TARBALL" "https://github.com/keycloak/keycloak/releases/download/26.0.6/keycloak-26.0.6.tar.gz" || { echo 'Could not download Keycloak tarball'; exit 1; }
    echo "Keycloak tarball downloaded to $KEYCLOAK_OID4VCI_TARBALL."
else
    echo "Keycloak tarball already exists at $KEYCLOAK_OID4VCI_TARBALL."
fi

# Unpack Keycloak tarball into the tools directory
if [ -d "$KC_INSTALL_DIR" ]; then
    echo "Directory $KC_INSTALL_DIR exists, removing it..."
    rm -rf "$KC_INSTALL_DIR" || { echo 'Could not remove Keycloak install'; exit 1; }
fi

echo "unpacking keycloak ..."
cd $TOOLS_DIR && tar xzf $KEYCLOAK_OID4VCI_TARBALL || { echo 'Could not unpack keycloak' ; exit 1; }
cd $WORK_DIR # undo directory change

# Generate or reuse keystore file
# If a keystore with the same base name as `KEYCLOAK_KEYSTORE_FILE` 
# is found at the root of project, it will be reused and not generated.
KEYCLOAK_KEYSTORE_FILE_BASENAME=$(basename "$KEYCLOAK_KEYSTORE_FILE")
if [ -f "$WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME" ]; then
    echo "Keystore $WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME exists, will be reused..."
    cp "$WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME" "$KEYCLOAK_KEYSTORE_FILE"
else
    ./generate_keystore.sh
fi

echo "Setup completed successfully."
