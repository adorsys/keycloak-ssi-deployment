#!/bin/bash

# Variables
source load_env.sh

if [ -f "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" ]; then
  echo "Config cli jar file exists..."
else 
  # Check if the CLI project folder already exists, if so remove and clone again...
  if [ -d "$KC_CLI_PROJECT_DIR" ]; then
    echo "Directory $KC_CLI_PROJECT_DIR exists. Removing it..."
    rm -rf "$KC_CLI_PROJECT_DIR" || { echo "Failed to remove directory $KC_CLI_PROJECT_DIR"; exit 1; }
  else
    echo "Directory does not exist"
    # Only clone the main branch of the Git repository if not existent
    echo "Cloning repository from ${REPO_URL}..."
    cd $TARGET_DIR && git clone "$REPO_URL" || { echo "Failed to clone repository"; exit 1; }
  fi

  # Navigate to the cloned repository
  cd "$KC_CLI_PROJECT_DIR" || { echo "Failed to navigate to $KC_CLI_PROJECT_DIR"; exit 1; }

  # Fetch all tags
  echo "Fetching tags from the repository..."
  git fetch --tags || { echo "Failed to fetch tags"; exit 1; }

  if [ -n "$TAG" ]; then
    # Switch to the desired release tag
    echo "Checking out tag $TAG..."
    git checkout tags/$TAG -b $TAG || { echo "Failed to checkout tag $TAG"; exit 1; }
  else
    echo "No tag specified. Using the default branch."
  fi

  # Build CLI tool
  ./mvnw clean install -DskipTests || { echo "Failed to build the CLI tool"; exit 1; }

  # Check if JAR file is created in the target directory
  if ls target/*.jar 1> /dev/null 2>&1; then
    echo "Build successful! JAR file created."
  else
    echo "Build failed! No JAR file found."
    exit 1
  fi
fi

# Export environment variables used by the realm JSON substitution
# these are referenced as env:KEYSTORE_PATH and env:KEYSTORE_PASSWORD in the JSON
export KEYSTORE_PATH="$KC_KEYSTORE_PATH"
export KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD"
export CLIENT_SECRET="$CLIENT_SECRET"
export ISSUER_BACKEND_URL="$ISSUER_BACKEND_URL"
export ISSUER_FRONTEND_URL="$ISSUER_FRONTEND_URL"
export ISSUER_DID="$ISSUER_DID"
export TEST_CLIENT_URL="$TEST_CLIENT_URL"

# If the realm already exists, remove it so the import can recreate it cleanly.
# This prevents HTTP 400 errors from the config CLI when updating components.
echo "Deleting existing realm $KEYCLOAK_REALM (if present)"
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server "$KEYCLOAK_URL" --realm master \
    --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD

# Use get realms and grep for the exact realm name
if $KC_INSTALL_DIR/bin/kcadm.sh get realms --fields realm | grep -q "\"realm\" : \"$KEYCLOAK_REALM\""; then
    echo "Realm $KEYCLOAK_REALM detected. Initiating complete deletion..."
    $KC_INSTALL_DIR/bin/kcadm.sh delete realms/$KEYCLOAK_REALM
    if [ $? -eq 0 ]; then
        echo "Realm $KEYCLOAK_REALM deleted successfully. Waiting for cleanup..."
        sleep 5
    else
        echo "Failed to delete realm $KEYCLOAK_REALM. Check if it was already deleted or if there are other issues."
    fi
else
    echo "Realm $KEYCLOAK_REALM not found. Proceeding with import."
fi


# Run the JAR file with the specified parameters
# When running locally, let the option keycloak.ssl-verify be false otherwise let it be true.
echo "Running the JAR file..."
java -DCLIENT_SECRET="$CLIENT_SECRET" \
     -DKEYCLOAK_EXTERNAL_ADDR="$KEYCLOAK_EXTERNAL_ADDR" \
     -DKEYCLOAK_KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD" \
     -DKC_KEYSTORE_PATH="$KC_KEYSTORE_PATH" \
     -DKEYCLOAK_REALM="$KEYCLOAK_REALM" \
     -DISSUER_BACKEND_URL="$ISSUER_BACKEND_URL" \
     -DISSUER_FRONTEND_URL="$ISSUER_FRONTEND_URL" \
     -DISSUER_DID="$ISSUER_DID" \
     -DSAML_ENTITYID="$ISSUER_DID" \
     -DTEST_CLIENT_URL="$TEST_CLIENT_URL" \
     -jar "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" \
     -Dimport-realm=true \
     --import.var-substitution.enabled=true \
     --keycloak.url="$KEYCLOAK_URL" \
     --keycloak.user="$KC_BOOTSTRAP_ADMIN_USERNAME" \
     --keycloak.password="$KC_BOOTSTRAP_ADMIN_PASSWORD" \
     --keycloak.ssl-verify=false \
     --logging.level.root=info \
     --import.files.locations="$KC_REALM_FILE" || { echo "Failed to run the JAR file"; exit 1; }

# After import, update sd-jwt authenticator
# echo "Ensuring sd-jwt authenticator VCT is configured"
# . ./update_sdjwt_vct.sh

echo "Script completed successfully."