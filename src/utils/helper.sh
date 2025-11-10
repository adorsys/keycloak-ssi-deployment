#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Keycloak SSI Deployment Helper Functions
# Common utilities for all deployment scripts
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Standardized Color Codes and Logging
# -----------------------------------------------------------------------------
# Only set colors if they haven't been set already (avoid conflicts with CLI)
[[ -z "${RED:-}" ]] && readonly RED='\033[0;31m'
[[ -z "${GREEN:-}" ]] && readonly GREEN='\033[0;32m'
[[ -z "${YELLOW:-}" ]] && readonly YELLOW='\033[1;33m'
[[ -z "${CYAN:-}" ]] && readonly CYAN='\033[0;36m'
[[ -z "${BLUE:-}" ]] && readonly BLUE='\033[1;34m'
[[ -z "${NC:-}" ]] && readonly NC='\033[0m' # No Color

# Standardized logging functions
log()     { printf "\n${CYAN}[INFO]${NC} %s\n" "$*"; }
warn()    { printf "\n${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
error()   { printf "\n${RED}[ERROR]${NC} %s\n" "$*" >&2; exit 1; }
success() { printf "\n${GREEN}[SUCCESS]${NC} %s\n" "$*"; }
debug()   { printf "\n${BLUE}[DEBUG]${NC} %s\n" "$*"; }


# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------
setup_environment() {
    # Set strict error handling
    set -euo pipefail
    IFS=$'\n\t'

    # Use WORK_DIR if already set (by CLI), otherwise determine it
    if [[ -z "${WORK_DIR:-}" ]]; then
        # Find the project root by looking for a known marker
        local search_dir="${PWD}"
        while [[ "$search_dir" != "/" && "$search_dir" != "" ]]; do
            if [[ -f "$search_dir/src/utils/helper.sh" || -f "$search_dir/docker-compose.yml" ]]; then
                WORK_DIR="$search_dir"
                break
            fi
            search_dir="$(dirname "$search_dir")"
        done

        if [[ -z "${WORK_DIR:-}" ]]; then
            error "Could not determine project root. Run from within the repository."
        fi
    fi

    # Load configuration from YAML with environment variable overrides
    load_configuration
}

# -----------------------------------------------------------------------------
# Configuration Loading
# -----------------------------------------------------------------------------
load_configuration() {
    local config_file="$WORK_DIR/config.yaml"
    local override_file="$WORK_DIR/config.override.yaml"

    # Check if yq is available
    if ! command -v yq &>/dev/null; then
        error "yq is required for configuration management. Please install yq."
        return 1
    fi

    # Check if config.yaml exists
    if [[ ! -f "$config_file" ]]; then
        error "config.yaml not found. Configuration file is required."
        return 1
    fi

    log "Loading configuration from $config_file"

    # Load base configuration from YAML
    load_yaml_config "$config_file"

    # Apply overrides from config.override.yaml if it exists
    if [[ -f "$override_file" ]]; then
        log "Applying overrides from $override_file"
        load_yaml_config "$override_file"
    fi
}

# -----------------------------------------------------------------------------
# YAML Configuration Loading
# -----------------------------------------------------------------------------
load_yaml_config() {
    local yaml_file="$1"
    local is_override=false

    # Check if this is an override file
    if [[ "$yaml_file" == *"override"* ]]; then
        is_override=true
    fi

    # Load project directories
    if [[ "$is_override" == true ]]; then
        export TARGET_DIR="$(yq '.project.target_dir' "$yaml_file" | envsubst)"
        export TOOLS_DIR="$(yq '.project.tools_dir' "$yaml_file" | envsubst)"
    else
        export TARGET_DIR="${TARGET_DIR:-$(yq '.project.target_dir' "$yaml_file" | envsubst)}"
        export TOOLS_DIR="${TOOLS_DIR:-$(yq '.project.tools_dir' "$yaml_file" | envsubst)}"
    fi

    # Load Keycloak setup
    if [[ "$is_override" == true ]]; then
        # Only override if the value exists in the override file
        local realm_value
        realm_value="$(yq '.keycloak.realm' "$yaml_file")"
        if [[ "$realm_value" != "null" && -n "$realm_value" ]]; then
            export KEYCLOAK_REALM="$realm_value"
        fi

        local version_value
        version_value="$(yq '.keycloak.version' "$yaml_file")"
        if [[ "$version_value" != "null" && -n "$version_value" ]]; then
            export KC_VERSION="$version_value"
        fi

        local branch_value
        branch_value="$(yq '.keycloak.target_branch' "$yaml_file")"
        if [[ "$branch_value" != "null" && -n "$branch_value" ]]; then
            export KC_TARGET_BRANCH="$branch_value"
        fi

        local oid4vci_value
        oid4vci_value="$(yq '.keycloak.oid4vci_dir' "$yaml_file")"
        if [[ "$oid4vci_value" != "null" && -n "$oid4vci_value" ]]; then
            export KC_OID4VCI="$oid4vci_value"
        fi

        local tarball_value
        tarball_value="$(yq '.keycloak.tarball_path' "$yaml_file")"
        if [[ "$tarball_value" != "null" && -n "$tarball_value" ]]; then
            export KEYCLOAK_TARBALL="$(echo "$tarball_value" | envsubst)"
        fi

        local install_value
        install_value="$(yq '.keycloak.install_dir' "$yaml_file")"
        if [[ "$install_value" != "null" && -n "$install_value" ]]; then
            export KC_INSTALL_DIR="$(echo "$install_value" | envsubst)"
        fi

        local repo_value
        repo_value="$(yq '.keycloak.repo_url' "$yaml_file")"
        if [[ "$repo_value" != "null" && -n "$repo_value" ]]; then
            export KC_REPO_URL="$repo_value"
        fi

        local admin_user_value
        admin_user_value="$(yq '.keycloak.bootstrap.admin_username' "$yaml_file")"
        if [[ "$admin_user_value" != "null" && -n "$admin_user_value" ]]; then
            export KC_BOOTSTRAP_ADMIN_USERNAME="$admin_user_value"
        fi

        local admin_pass_value
        admin_pass_value="$(yq '.keycloak.bootstrap.admin_password' "$yaml_file")"
        if [[ "$admin_pass_value" != "null" && -n "$admin_pass_value" ]]; then
            export KC_BOOTSTRAP_ADMIN_PASSWORD="$admin_pass_value"
        fi
    else
        export KC_TARGET_BRANCH="${KC_TARGET_BRANCH:-$(yq '.keycloak.target_branch' "$yaml_file")}"
        export KC_VERSION="${KC_VERSION:-$(yq '.keycloak.version' "$yaml_file")}"
        export KC_OID4VCI="${KC_OID4VCI:-$(yq '.keycloak.oid4vci_dir' "$yaml_file")}"
        export KEYCLOAK_TARBALL="${KEYCLOAK_TARBALL:-$(yq '.keycloak.tarball_path' "$yaml_file" | envsubst)}"
        export KC_INSTALL_DIR="${KC_INSTALL_DIR:-$(yq '.keycloak.install_dir' "$yaml_file" | envsubst)}"
        export KC_REPO_URL="${KC_REPO_URL:-$(yq '.keycloak.repo_url' "$yaml_file")}"
        export KC_BOOTSTRAP_ADMIN_USERNAME="${KC_BOOTSTRAP_ADMIN_USERNAME:-$(yq '.keycloak.bootstrap.admin_username' "$yaml_file")}"
        export KC_BOOTSTRAP_ADMIN_PASSWORD="${KC_BOOTSTRAP_ADMIN_PASSWORD:-$(yq '.keycloak.bootstrap.admin_password' "$yaml_file")}"
        export KEYCLOAK_REALM="${KEYCLOAK_REALM:-$(yq '.keycloak.realm' "$yaml_file")}"
    fi

    # Load keystore configuration
    if [[ "$is_override" == true ]]; then
        export KEYCLOAK_KEYSTORE_FILE="$(yq '.keystore.file' "$yaml_file" | envsubst)"
        export KEYCLOAK_KEYSTORE_TYPE="$(yq '.keystore.type' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_PASSWORD="$(yq '.keystore.password' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS="$(yq '.keystore.aliases.ecdsa_key' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS="$(yq '.keystore.aliases.rsa_sig_key' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS="$(yq '.keystore.aliases.rsa_enc_key' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS="$(yq '.keystore.aliases.hmac_sig_key' "$yaml_file")"
        export KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS="$(yq '.keystore.aliases.aes_enc_key' "$yaml_file")"
    else
        export KEYCLOAK_KEYSTORE_FILE="${KEYCLOAK_KEYSTORE_FILE:-$(yq '.keystore.file' "$yaml_file" | envsubst)}"
        export KEYCLOAK_KEYSTORE_TYPE="${KEYCLOAK_KEYSTORE_TYPE:-$(yq '.keystore.type' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_PASSWORD="${KEYCLOAK_KEYSTORE_PASSWORD:-$(yq '.keystore.password' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS="${KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS:-$(yq '.keystore.aliases.ecdsa_key' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS="${KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS:-$(yq '.keystore.aliases.rsa_sig_key' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS="${KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS:-$(yq '.keystore.aliases.rsa_enc_key' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS="${KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS:-$(yq '.keystore.aliases.hmac_sig_key' "$yaml_file")}"
        export KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS="${KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS:-$(yq '.keystore.aliases.aes_enc_key' "$yaml_file")}"
    fi

    # Load user credentials
    if [[ "$is_override" == true ]]; then
        export USER_FRANCIS_NAME="$(yq '.users.francis.name' "$yaml_file")"
        export USER_FRANCIS_PASSWORD="$(yq '.users.francis.password' "$yaml_file")"
        export FRANCIS_KEYSTORE_FILE="$(yq '.users.francis.keystore.file' "$yaml_file" | envsubst)"
        export FRANCIS_KEYSTORE_PASSWORD="$(yq '.users.francis.keystore.password' "$yaml_file")"
        export FRANCIS_KEYSTORE_TYPE="$(yq '.users.francis.keystore.type' "$yaml_file")"
        export FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS="$(yq '.users.francis.keystore.ecdsa_alias' "$yaml_file")"
    else
        export USER_FRANCIS_NAME="${USER_FRANCIS_NAME:-$(yq '.users.francis.name' "$yaml_file")}"
        export USER_FRANCIS_PASSWORD="${USER_FRANCIS_PASSWORD:-$(yq '.users.francis.password' "$yaml_file")}"
        export FRANCIS_KEYSTORE_FILE="${FRANCIS_KEYSTORE_FILE:-$(yq '.users.francis.keystore.file' "$yaml_file" | envsubst)}"
        export FRANCIS_KEYSTORE_PASSWORD="${FRANCIS_KEYSTORE_PASSWORD:-$(yq '.users.francis.keystore.password' "$yaml_file")}"
        export FRANCIS_KEYSTORE_TYPE="${FRANCIS_KEYSTORE_TYPE:-$(yq '.users.francis.keystore.type' "$yaml_file")}"
        export FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS="${FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS:-$(yq '.users.francis.keystore.ecdsa_alias' "$yaml_file")}"
    fi

    # Load client credentials
    if [[ "$is_override" == true ]]; then
        export CLIENT_SECRET="$(yq '.clients.secret' "$yaml_file")"
    else
        export CLIENT_SECRET="${CLIENT_SECRET:-$(yq '.clients.secret' "$yaml_file")}"
    fi

    # Load URLs
    if [[ "$is_override" == true ]]; then
        export KEYCLOAK_HTTPS_PORT="$(yq '.urls.https_port' "$yaml_file")"
        export KEYCLOAK_ADMIN_ADDR="$(yq '.urls.admin_addr' "$yaml_file" | envsubst)"
        export ISSUER_DID="$(yq '.urls.issuer_did' "$yaml_file" | envsubst)"
        export ISSUER_BACKEND_URL="$(yq '.urls.issuer_backend' "$yaml_file")"
        export ISSUER_FRONTEND_URL="$(yq '.urls.issuer_frontend' "$yaml_file")"
        export TEST_CLIENT_URL="$(yq '.urls.test_client' "$yaml_file")"
    else
        export KEYCLOAK_HTTPS_PORT="${KEYCLOAK_HTTPS_PORT:-$(yq '.urls.https_port' "$yaml_file")}"
        export KEYCLOAK_ADMIN_ADDR="${KEYCLOAK_ADMIN_ADDR:-$(yq '.urls.admin_addr' "$yaml_file" | envsubst)}"
        export ISSUER_DID="${ISSUER_DID:-$(yq '.urls.issuer_did' "$yaml_file" | envsubst)}"
        export ISSUER_BACKEND_URL="${ISSUER_BACKEND_URL:-$(yq '.urls.issuer_backend' "$yaml_file")}"
        export ISSUER_FRONTEND_URL="${ISSUER_FRONTEND_URL:-$(yq '.urls.issuer_frontend' "$yaml_file")}"
        export TEST_CLIENT_URL="${TEST_CLIENT_URL:-$(yq '.urls.test_client' "$yaml_file")}"
    fi

    # Load SSL configuration
    if [[ "$is_override" == true ]]; then
        export KC_SERVER_KEY="$(yq '.ssl.server_key' "$yaml_file" | envsubst)"
        export KC_SERVER_CERT="$(yq '.ssl.server_cert' "$yaml_file" | envsubst)"
        export KC_TRUST_STORE="$(yq '.ssl.trust_store' "$yaml_file" | envsubst)"
        export KC_TRUST_STORE_PASS="$(yq '.ssl.trust_store_pass' "$yaml_file")"
    else
        export KC_SERVER_KEY="${KC_SERVER_KEY:-$(yq '.ssl.server_key' "$yaml_file" | envsubst)}"
        export KC_SERVER_CERT="${KC_SERVER_CERT:-$(yq '.ssl.server_cert' "$yaml_file" | envsubst)}"
        export KC_TRUST_STORE="${KC_TRUST_STORE:-$(yq '.ssl.trust_store' "$yaml_file" | envsubst)}"
        export KC_TRUST_STORE_PASS="${KC_TRUST_STORE_PASS:-$(yq '.ssl.trust_store_pass' "$yaml_file")}"
    fi

    # Load database configuration
    if [[ "$is_override" == true ]]; then
        export KC_DB_EXPOSED_PORT="$(yq '.database.exposed_port' "$yaml_file")"
        export KC_DB_NAME="$(yq '.database.name' "$yaml_file")"
        export KC_DB_USERNAME="$(yq '.database.username' "$yaml_file")"
        export KC_DB_PASSWORD="$(yq '.database.password' "$yaml_file")"
    else
        export KC_DB_EXPOSED_PORT="${KC_DB_EXPOSED_PORT:-$(yq '.database.exposed_port' "$yaml_file")}"
        export KC_DB_NAME="${KC_DB_NAME:-$(yq '.database.name' "$yaml_file")}"
        export KC_DB_USERNAME="${KC_DB_USERNAME:-$(yq '.database.username' "$yaml_file")}"
        export KC_DB_PASSWORD="${KC_DB_PASSWORD:-$(yq '.database.password' "$yaml_file")}"
    fi

    # Load start command
    if [[ "$is_override" == true ]]; then
        export KC_START="$(yq '.start_command' "$yaml_file" | envsubst)"
    else
        export KC_START="${KC_START:-$(yq '.start_command' "$yaml_file" | envsubst)}"
    fi

    # Load CLI configuration
    if [[ "$is_override" == true ]]; then
        export TAG="$(yq '.cli.tag' "$yaml_file")"
        export KC_REALM_FILE="$(yq '.cli.realm_file' "$yaml_file")"
        export KC_KEYSTORE_PATH="$(yq '.cli.keystore_path' "$yaml_file" | envsubst)"
    else
        export TAG="${TAG:-$(yq '.cli.tag' "$yaml_file")}"
        export KC_REALM_FILE="${KC_REALM_FILE:-$(yq '.cli.realm_file' "$yaml_file")}"
        export KC_KEYSTORE_PATH="${KC_KEYSTORE_PATH:-$(yq '.cli.keystore_path' "$yaml_file" | envsubst)}"
    fi
}

# -----------------------------------------------------------------------------
# Environment Variable Injection
# -----------------------------------------------------------------------------
inject_environment_variables() {
    local yaml_content="$1"

    # Use yq to process environment variable injection
    # This handles ${VAR_NAME} and ${VAR_NAME:-default} syntax
    echo "$yaml_content" | yq '(.. | select(tag == "!!str")) |= envsubst'
}

# -----------------------------------------------------------------------------
# Fallback Environment Loading
# -----------------------------------------------------------------------------
load_env_fallback() {
    # Load environment variables from .env files (for backward compatibility)
    if [[ -f "$WORK_DIR/.env" ]]; then
        # shellcheck disable=SC1090
        . "$WORK_DIR/.env"
    fi
    if [[ -f "$WORK_DIR/../env/.env" ]]; then
        log "Using local properties from $WORK_DIR/../env/.env"
        # shellcheck disable=SC1090
        . "$WORK_DIR/../env/.env"
    fi
}

# -----------------------------------------------------------------------------
# Keycloak Process Management
# -----------------------------------------------------------------------------
get_keycloak_pid() {
    if command -v pgrep &>/dev/null; then
        pgrep -f keycloak | head -n1 || true
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            ps aux | grep -i '[q]uarkus' | awk 'NR==1{print $2}' || true
        else
            ps aux | grep -i '[k]eycloak' | awk 'NR==1{print $2}' || true
        fi
    fi
}

stop_keycloak() {
    local keycloak_pid
    keycloak_pid="$(get_keycloak_pid || true)"

    if [[ -n "$keycloak_pid" ]]; then
        log "Keycloak instance found (PID: $keycloak_pid). Shutting it down..."
        kill "$keycloak_pid" || warn "Failed to kill process $keycloak_pid"
        # Wait for process to terminate
        sleep 2
        if kill -0 "$keycloak_pid" 2>/dev/null; then
            warn "Process still running, force killing..."
            kill -9 "$keycloak_pid" 2>/dev/null || true
            sleep 1
        fi
        log "Keycloak stopped."
    else
        log "No running Keycloak instance found."
    fi

    # -------------------------------------------------------------------------
    # Stop and remove database container + volume using Docker Compose
    # -------------------------------------------------------------------------
    DOCKER_COMPOSE_FILE="${WORK_DIR}/docker-compose.yml"
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        DOCKER_COMPOSE_COMMAND="$(detect_docker_compose)"
        log "Stopping and removing database container..."
        eval "$DOCKER_COMPOSE_COMMAND -f \"$DOCKER_COMPOSE_FILE\" down -v db" || \
            warn "Failed to stop/remove database container or volume. You may need to clean manually."
        log "Database container and volume removed."
    else
        warn "docker-compose.yml not found. Cannot stop DB container."
    fi
}


# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------
urlencode() {
    jq -nr --arg str "$1" '$str|@uri'
}



# -----------------------------------------------------------------------------
# Docker Compose Detection
# -----------------------------------------------------------------------------
detect_docker_compose() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        error "Neither 'docker compose' (v2) nor 'docker-compose' (v1) is installed."
    fi
}

# -----------------------------------------------------------------------------
# Directory Management
# -----------------------------------------------------------------------------
ensure_directory_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
}

# -----------------------------------------------------------------------------
# Prerequisite Checks
# -----------------------------------------------------------------------------
check_dependencies() {
    local missing_deps=()
    for dep in openssl keytool jq figlet yq; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}. Please install them and try again."
    fi
}

# -----------------------------------------------------------------------------
# Script Initialization
# -----------------------------------------------------------------------------
init_script() {
    # Ensure environment and WORK_DIR are initialized
    setup_environment

    # Log script start
    local script_name
    if [[ ${#BASH_SOURCE[@]} -gt 1 ]]; then
        script_name="$(basename "${BASH_SOURCE[1]}")"
    else
        script_name="$(basename "${BASH_SOURCE[0]}")"
    fi
    log "Starting $script_name"
}

# -----------------------------------------------------------------------------
# Export functions for use in other scripts
# -----------------------------------------------------------------------------
export -f log warn error success
export -f setup_environment get_keycloak_pid stop_keycloak
export -f urlencode detect_docker_compose init_script ensure_directory_exists check_dependencies
