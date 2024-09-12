#!/bin/bash

# Variables
source load_env.sh

# Check if the CLI project folder already exits, if so remove and clone again...
if [ -d "$KC_CLI_PROJECT_DIR" ]; then
  echo "Directory $KC_CLI_PROJECT_DIR exists. Removing it..."
  rm -rf "$KC_CLI_PROJECT_DIR" || { echo "Failed to remove directory $KC_CLI_PROJECT_DIR"; exit 1; }
else
  echo "Directory does not exist"
fi

# Clone the main branch of the Git repository
echo "Cloning repository from $REPO_URL..."
cd $KC_CLI_DIR && git clone --branch main "$REPO_URL" || { echo "Failed to clone repository"; exit 1; }

# Navigate to cloned dir and build CLI tool
cd "$KC_CLI_PROJECT_DIR" && ./mvnw clean install -DskipTests || { echo "Failed to build the CLI tool"; exit 1; }

# Check if JAR file is created in the target directory
if ls target/*.jar 1> /dev/null 2>&1; then
  echo "Build successful! JAR file created."
else
  echo "Build failed! No JAR file found."
  exit 1
fi

# Define a temporary file to store the modified realm.json
MODIFIED_REALM_JSON="modified_realm.json"

# Replace the placeholders 'KEYCLOAK_KEYSTORE_PATH','KEYCLOAK_KEYSTORE_PASSWORD' and 'CLIENT_SECRETin' in the realm.json file with the actual value from the .env
sed -e "s|KC_KEYSTORE_PATH|$KC_KEYSTORE_PATH|g" \
    -e "s|KEYCLOAK_KEYSTORE_PASSWORD|$KEYCLOAK_KEYSTORE_PASSWORD|g" \
    -e "s|CLIENT_SECRET|$CLIENT_SECRET|g" \
    $KC_REALM_FILE > $MODIFIED_REALM_JSON

# Run the JAR file with the specified parameters
echo "Running the JAR file..."
java -jar target/$KC_CLI_JAR_FILE \
  -Dimport-realm="true" \
  -Dforce="true" \
  --keycloak.url="$KEYCLOAK_URL" \
  --keycloak.user="$KEYCLOAK_ADMIN" \
  --keycloak.password="$KEYCLOAK_ADMIN_PASSWORD" \
  --keycloak.ssl-verify="true" \
  --import.files.locations="$MODIFIED_REALM_JSON" || { echo "Failed to run the JAR file"; exit 1; }
echo "Script completed successfully."

#Removing MODIFIED_REALM_JSON form memory
unset MODIFIED_REALM_JSON