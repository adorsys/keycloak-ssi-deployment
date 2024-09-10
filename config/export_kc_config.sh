#!/bin/bash

# Variables
source .env

# Check if the CLI project folder already exits, if so remove and clone again...
if [ -d "$PROJECT_DIR" ]; then
  echo "Directory $PROJECT_DIR exists. Removing it..."
  rm -rf "$PROJECT_DIR" || { echo "Failed to remove directory $PROJECT_DIR"; exit 1; }
else
  echo "Directory does not exist"
fi

# Clone the main branch of the Git repository
echo "Cloning repository from $REPO_URL..."
cd $KC_CLI_DIR && git clone --branch main "$REPO_URL" || { echo "Failed to clone repository"; exit 1; }

# Navigate to cloned dir and build CLI tool
cd "$PROJECT_DIR" && ./mvnw clean install -DskipTests || { echo "Failed to build the CLI tool"; exit 1; }

# Check if JAR file is created in the target directory
if ls target/*.jar 1> /dev/null 2>&1; then
  echo "Build successful! JAR file created."
else
  echo "Build failed! No JAR file found."
  exit 1
fi

# Define a temporary file to store the modified realm.json
MODIFIED_REALM_JSON="modified_realm.json"

# Replace the placeholder 'KEYCLOAK_KEYSTORE_PATH' in the realm.json file with the actual value from the .env
sed -e "s|KC_KEYSTORE_PATH|$KC_KEYSTORE_PATH|g" \
    -e "s|KEYCLOAK_KEYSTORE_PASSWORD|$KEYCLOAK_KEYSTORE_PASSWORD|g" \
    -e "s|CLIENT_SECRET|$CLIENT_SECRET|g" \
    $IMPORT_PATH > $MODIFIED_REALM_JSON


# Run the JAR file with the specified parameters
echo "Running the JAR file..."
java -jar target/$JAR_FILE \
  -Dimport-realm="true" \
  -Dforce="true" \
  --keycloak.url="$KEYCLOAK_URL" \
  --keycloak.user="$KEYCLOAK_USER" \
  --keycloak.password="$KEYCLOAK_PASSWORD" \
  --keycloak.ssl-verify="true" \
  --import.files.locations="$MODIFIED_REALM_JSON" || { echo "Failed to run the JAR file"; exit 1; }
echo "Script completed successfully."