#!/bin/bash

# Source common env variables
. load_env.sh

# Function to ensure directory existence
ensure_directory_exists() {
    dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist, creating..."
        mkdir -p "$dir" || { echo "Failed to create $dir"; exit 1; }
        echo "Directory $dir created."
    else
        echo "Directory $dir already exists."
    fi
}

# Ensure required directories exist
ensure_directory_exists "$TARGET_DIR"
ensure_directory_exists "$TOOLS_DIR"

# Function to download the Keycloak tarball if it doesn't already exist
download_tarball() {
    if [ ! -f "$KEYCLOAK_TARBALL" ]; then
        echo "Downloading Keycloak tarball..."
        curl -L -o "$KEYCLOAK_TARBALL" "https://github.com/keycloak/keycloak/releases/download/$KC_VERSION/keycloak-$KC_VERSION.tar.gz" || {
            echo "Could not download Keycloak tarball";
            exit 1;
        }
        echo "Keycloak tarball downloaded to $KEYCLOAK_TARBALL."
    else
        echo "Keycloak tarball already exists at $KEYCLOAK_TARBALL."
    fi
}

# Function to clone the custom Keycloak repository and build it if necessary
clone_and_build_keycloak() {
    if [ ! -d "$TARGET_DIR/$KC_OID4VCI" ]; then
        echo "Cloning custom Keycloak repository..."
        cd $TARGET_DIR && git clone --depth 1 --branch $KC_TARGET_BRANCH https://github.com/adorsys/keycloak-oid4vc.git $TARGET_DIR/$KC_OID4VCI || {
            echo "Could not clone the repository";
            exit 1;
        }
        echo "Keycloak cloned into $TARGET_DIR/$KC_OID4VCI."
    else
        echo "Keycloak repository already exists at $TARGET_DIR/$KC_OID4VCI."
    fi

    # Check if the Keycloak build artifact exists, if not, build it
    if [ ! -f "$TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz" ]; then
        echo "File $TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz does not exist, building keycloak..."
        cd "$TARGET_DIR/$KC_OID4VCI" && $TARGET_DIR/$KC_OID4VCI/mvnw clean install -DskipTests || {
            echo "Could not build Keycloak";
            exit 1;
        }
        echo "Keycloak built successfully."
    else
        echo "Keycloak build artifact already exists. Skipping build."
    fi
}

# Set KC_USE_UPSTREAM to "true" to use the upstream Keycloak tarball for installation (download from release).
# Set to "false" to build Keycloak from a cloned branch with custom changes.
if [ "$KC_VERSION" != "999.0.0-SNAPSHOT" ]; then
  KC_USE_UPSTREAM=true
else
  KC_USE_UPSTREAM=false
fi

# Function to unpack the Keycloak tarball to the installation directory
unpack_keycloak() {
    # Ensure the tarball path is set correctly based on whether using upstream or custom build
    if [ "$KC_USE_UPSTREAM" = true ]; then
        TAR_FILE="$KEYCLOAK_TARBALL"
    else
        TAR_FILE="$TARGET_DIR/$KC_OID4VCI/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz"
    fi

    # Remove existing installation if it exists
    if [ -d "$KC_INSTALL_DIR" ]; then
        echo "Removing existing Keycloak installation..."
        rm -rf "$KC_INSTALL_DIR" || {
            echo "Failed to remove existing installation";
            exit 1;
        }
    fi

    # Unpack the Keycloak tarball
    echo "Unpacking Keycloak..."
    tar xzf "$TAR_FILE" -C "$TOOLS_DIR" || {
        echo "Could not unpack Keycloak tarball";
        exit 1;
    }
    echo "Keycloak unpacked to $KC_INSTALL_DIR."
}

# Main script logic to determine whether to use upstream or custom Keycloak
if [ "$KC_USE_UPSTREAM" = true ]; then
    echo "Using upstream Keycloak tarball..."
    download_tarball
    unpack_keycloak
else
    echo "Building custom Keycloak from source..."
    clone_and_build_keycloak
    unpack_keycloak
fi

# Restore original working directory
cd "$WORK_DIR" || { echo "Could not return to working directory"; exit 1; }

if [ ! -f "$KC_TRUST_STORE" ]; then
    echo "Generating SSl keys..." && \
    source $WORK_DIR/generate-kc-certs.sh
fi

# Generate or reuse keystore file
# If a keystore with the same base name as `KEYCLOAK_KEYSTORE_FILE` 
# is found at the root of project, it will be reused and not generated.
KEYCLOAK_KEYSTORE_FILE_BASENAME=$(basename "$KEYCLOAK_KEYSTORE_FILE")
if [ -f "$WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME" ]; then
    echo "Keystore $WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME exists, will be reused..."
    cp "$WORK_DIR/$KEYCLOAK_KEYSTORE_FILE_BASENAME" "$KEYCLOAK_KEYSTORE_FILE"
else
    ./generate_keystore.sh || { echo "Failed to generate keystore"; exit 1; }
fi

echo "Setup completed successfully."
