#!/bin/bash

# Variables
source .env

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

# Run the JAR file with the specified parameters
# When running locally , let the option keycloak.ssl-verify be false otherwise let it be true.
echo "Running the JAR file..."
java -DCLIENT_SECRET="$CLIENT_SECRET" \
     -DKEYCLOAK_EXTERNAL_ADDR="$KEYCLOAK_EXTERNAL_ADDR" \
     -DKEYCLOAK_KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD" \
     -DKC_KEYSTORE_PATH="$KC_KEYSTORE_PATH" \
     -jar target/$KC_CLI_JAR_FILE \
     -Dimport-realm=true \
     --import.var-substitution.enabled=true \
     --keycloak.url="$KEYCLOAK_URL" \
     --keycloak.user="$KEYCLOAK_ADMIN" \
     --keycloak.password="$KEYCLOAK_ADMIN_PASSWORD" \
     --keycloak.ssl-verify=false \
     --import.files.locations="$KC_REALM_FILE" || { echo "Failed to run the JAR file"; exit 1; }
echo "Script completed successfully."