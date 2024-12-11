#!/bin/sh

# Define paths for the environment files
DEFAULT_ENV_FILE="/opt/keycloak/.env"
CUSTOM_ENV_FILE="/opt/keycloak/env/.env"

# Function to safely export variables from a .env file
load_env_file() {
  local env_file=$1
  if [ -f "$env_file" ]; then
    echo "Loading variables from: $env_file"
    # Use 'envsubst' to handle special characters and spaces correctly
    set -a
    . "$env_file" || { echo "Error loading $env_file"; exit 1; }
    set +a
  else
    echo "Env file not found: $env_file"
  fi
}

# Load the default .env file first
load_env_file "$DEFAULT_ENV_FILE"

# If a custom .env file is provided, overwrite variables
if [ -f "$CUSTOM_ENV_FILE" ]; then
  load_env_file "$CUSTOM_ENV_FILE"
else
  echo "No custom .env file provided. Using default variables only."
fi

# Start Keycloak
cd $KC_INSTALL_DIR
exec bin/kc.sh $KC_START $KC_DB_OPTS--features=oid4vc-vci
