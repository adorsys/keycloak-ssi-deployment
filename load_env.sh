#!/bin/bash

CONFIG_FILE="./config/config.yaml"
LOCAL_CONFIG_FILE="./config/config-local.yaml"
TEMP_CONFIG_FILE=$(mktemp)

# Check if yq is installed
if ! command -v yq &> /dev/null
then
    echo "Error: yq (YAML processor) is not installed."
    echo "Please install yq (e.g., 'sudo snap install yq' or 'brew install yq')."
    exit 1
fi

# Function to get a value from the YAML config file
# Usage: get_config_value <yaml_path> <env_var_name>
get_config_value() {
    local yaml_path=$1
    local env_var_name=$2
    local value=$(yq e "$yaml_path" "$TEMP_CONFIG_FILE")
    
    # Handle null/empty values
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "Warning: Configuration value for $yaml_path is empty or null." >&2
        return
    fi

    # Perform variable substitution if the value contains $(...) or ${...}
    # This is necessary because yq returns the literal string, and we need shell expansion.
    # We use 'eval' carefully here.
    if [[ "$value" =~ \$ ]]; then
        value=$(eval echo "$value")
    fi

    # Export the variable, respecting existing environment variables for overrides
    if [ -z "${!env_var_name}" ]; then
        export "$env_var_name"="$value"
    else
        echo "Using existing environment variable override for $env_var_name: ${!env_var_name}" >&2
    fi
}


# Function to inject an environment variable into the YAML tree if it exists
# Usage: inject_secret <yaml_path> <env_var_name>
inject_secret() {
    local yaml_path=$1
    local env_var_name=$2
    local secret_value="${!env_var_name}"

    if [ -n "$secret_value" ]; then
        echo "Injecting secret from environment variable $env_var_name into $yaml_path" >&2
        # Use yq to update the temporary config file
        yq e "$yaml_path = \"$secret_value\"" -i "$TEMP_CONFIG_FILE"
    fi
}

# --- Configuration Setup ---

# 1. Merge config-local.yaml over config.yaml if it exists
if [ -f "$LOCAL_CONFIG_FILE" ]; then
    echo "Merging $LOCAL_CONFIG_FILE over $CONFIG_FILE" >&2
    yq e "load(\"$CONFIG_FILE\") * load(\"$LOCAL_CONFIG_FILE\")" > "$TEMP_CONFIG_FILE"
else
    echo "Using $CONFIG_FILE as primary configuration" >&2
    cp "$CONFIG_FILE" "$TEMP_CONFIG_FILE"
fi

# 2. Inject sensitive secrets from environment variables into the merged configuration
inject_secret ".keycloak.bootstrap.admin.password" "KC_BOOTSTRAP_ADMIN_PASSWORD"
inject_secret ".database.password" "KC_DB_PASSWORD"
inject_secret ".users.francis.password" "USER_FRANCIS_PASSWORD"
inject_secret ".users.francis.keystore.password" "FRANCIS_KEYSTORE_PASSWORD"
inject_secret ".client.openid4vc_rest_api.secret" "CLIENT_SECRET"

# 3. Load all configuration values into environment variables

# Work directories
get_config_value ".work.dir" "WORK_DIR"
get_config_value ".work.target_dir" "TARGET_DIR"
get_config_value ".tools.dir" "TOOLS_DIR"

# Keycloak core
get_config_value ".keycloak.target_branch" "KC_TARGET_BRANCH"
get_config_value ".keycloak.version" "KC_VERSION"
get_config_value ".keycloak.oid4vci" "KC_OID4VCI"
get_config_value ".keycloak.tarball" "KEYCLOAK_TARBALL"
get_config_value ".keycloak.install_dir" "KC_INSTALL_DIR"
get_config_value ".keycloak.repo_url" "KC_REPO_URL"
get_config_value ".keycloak.https_port" "KEYCLOAK_HTTPS_PORT"
get_config_value ".keycloak.realm" "KEYCLOAK_REALM"

# Keycloak Admin/Bootstrap
get_config_value ".keycloak.bootstrap.admin.username" "KC_BOOTSTRAP_ADMIN_USERNAME"
get_config_value ".keycloak.bootstrap.admin.password" "KC_BOOTSTRAP_ADMIN_PASSWORD"
get_config_value ".keycloak.admin_addr" "KEYCLOAK_ADMIN_ADDR"
get_config_value ".keycloak.external_addr" "KEYCLOAK_EXTERNAL_ADDR"

# Keycloak Keystore
get_config_value ".keycloak.keystore.file" "KEYCLOAK_KEYSTORE_FILE"
get_config_value ".keycloak.keystore.type" "KEYCLOAK_KEYSTORE_TYPE"
get_config_value ".keycloak.keystore.password" "KEYCLOAK_KEYSTORE_PASSWORD"
get_config_value ".keycloak.keystore.aliases.ecdsa" "KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS"
get_config_value ".keycloak.keystore.aliases.rsa_sig" "KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS"
get_config_value ".keycloak.keystore.aliases.rsa_enc" "KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS"
get_config_value ".keycloak.keystore.aliases.hmac_sig" "KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS"
get_config_value ".keycloak.keystore.aliases.aes_enc" "KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS"
get_config_value ".keycloak.keystore.path" "KC_KEYSTORE_PATH"

# Keycloak SSL
get_config_value ".keycloak.ssl.server_key" "KC_SERVER_KEY"
get_config_value ".keycloak.ssl.server_cert" "KC_SERVER_CERT"
get_config_value ".keycloak.ssl.trust_store" "KC_TRUST_STORE"
get_config_value ".keycloak.ssl.trust_store_pass" "KC_TRUST_STORE_PASS"

# Keycloak Start Command
get_config_value ".keycloak.start_command" "KC_START"

# Database
get_config_value ".database.exposed_port" "KC_DB_EXPOSED_PORT"
get_config_value ".database.name" "KC_DB_NAME"
get_config_value ".database.username" "KC_DB_USERNAME"
get_config_value ".database.password" "KC_DB_PASSWORD"

# Users
get_config_value ".users.francis.name" "USER_FRANCIS_NAME"
get_config_value ".users.francis.password" "USER_FRANCIS_PASSWORD"
get_config_value ".users.francis.keystore.file" "FRANCIS_KEYSTORE_FILE"
get_config_value ".users.francis.keystore.password" "FRANCIS_KEYSTORE_PASSWORD"
get_config_value ".users.francis.keystore.type" "FRANCIS_KEYSTORE_TYPE"
get_config_value ".users.francis.keystore.aliases.ecdsa" "FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS"

# Client
get_config_value ".client.openid4vc_rest_api.secret" "CLIENT_SECRET"

# Issuer
get_config_value ".issuer.did" "ISSUER_DID"
get_config_value ".issuer.backend_url" "ISSUER_BACKEND_URL"
get_config_value ".issuer.frontend_url" "ISSUER_FRONTEND_URL"

# Test
get_config_value ".test.client_url" "TEST_CLIENT_URL"

# Keycloak Config CLI
get_config_value ".keycloak_config_cli.repo_url" "REPO_URL"
get_config_value ".keycloak_config_cli.jar_file" "KC_CLI_JAR_FILE"
get_config_value ".keycloak_config_cli.tag" "TAG"
get_config_value ".keycloak_config_cli.realm_file" "KC_REALM_FILE"
get_config_value ".keycloak_config_cli.project_dir" "KC_CLI_PROJECT_DIR"
get_config_value ".keycloak.admin_addr" "KEYCLOAK_URL" # KEYCLOAK_URL uses KEYCLOAK_ADMIN_ADDR

# Handle ISSUER_DID calculation which depends on KEYCLOAK_EXTERNAL_ADDR and KEYCLOAK_REALM
# Since these are now exported, we can calculate ISSUER_DID if it wasn't overridden.
if [ -z "$ISSUER_DID" ]; then
    export ISSUER_DID="${KEYCLOAK_EXTERNAL_ADDR}/realms/${KEYCLOAK_REALM}"
fi

# Clean up temporary file on exit
trap "rm -f $TEMP_CONFIG_FILE" EXIT
