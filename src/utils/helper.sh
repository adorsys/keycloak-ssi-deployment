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
                export WORK_DIR # Export WORK_DIR so it's available for envsubst
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
# YAML Configuration Export
# Exports YAML properties as uppercase, underscore-separated environment variables
# -----------------------------------------------------------------------------
export_yaml_as_env() {
    local yaml_files=("$@")
    local merged_props

    # Check if yq is available
    if ! command -v yq &>/dev/null; then
        error "yq is required for configuration management. Please install yq (version 4+)."
        return 1
    fi

    # Define the merge command: merge all files, with later files overriding earlier ones
    local yq_merge_command=". as \$item ireduce ({}; . * \$item)"

    # 1. Merge config files, flatten to properties, and clean up for shell export.
    #    Store this raw output for two passes.
    local raw_props_output=$(yq eval-all "$yq_merge_command | to_props" "${yaml_files[@]}" | \
        sed -E 's/^[[:space:]]*//; s/[[:space:]]*=[[:space:]]*/=/' | \
        grep -vE '^\s*#' | \
        grep -E '^[a-zA-Z_][a-zA-Z0-9_.]*='
    )

    # Pass 1: Export all variables with their raw values first.
    # This makes all potential reference targets available as environment variables.
    set +u
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        local env_var_name
        env_var_name=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
        # Export the raw value
        export "$env_var_name"="$value"
        case "$key" in
            "keycloak_endpoints.https_port")
                export KEYCLOAK_HTTPS_PORT="$value"
                ;;
            "keycloak_endpoints.admin_addr")
                export KEYCLOAK_ADMIN_ADDR="$value"
                ;;
        esac
    done <<< "$raw_props_output"
    set -u # Restore 'nounset'

    # Pass 2: Now that all variables are exported, re-evaluate and export with substitution.
    set +u # Temporarily disable 'nounset'
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        local env_var_name
        env_var_name=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
        # Resolve placeholders using envsubst, now that all variables are in the environment
        local resolved_value
        resolved_value=$(echo "$value" | envsubst)
        # Re-export the variable with its resolved value
        export "$env_var_name"="$resolved_value"
        case "$key" in
            "keycloak_endpoints.https_port")
                export KEYCLOAK_HTTPS_PORT="$resolved_value"
                ;;
            "keycloak_endpoints.admin_addr")
                export KEYCLOAK_ADMIN_ADDR="$resolved_value"
                ;;
            "keycloak_endpoints.issuer_did")
                export KEYCLOAK_ISSUER_DID="$resolved_value"
                ;;
        esac
    done <<< "$raw_props_output"
    set -u # Restore 'nounset'

    # Derived aliases for convenience
    [[ -n "${KEYCLOAK_ENDPOINTS_ADMIN_ADDR:-}" ]] && export KEYCLOAK_ADMIN_ADDR="${KEYCLOAK_ENDPOINTS_ADMIN_ADDR}"
    [[ -n "${KEYCLOAK_ENDPOINTS_ISSUER_DID:-}" ]] && export KEYCLOAK_ISSUER_DID="${KEYCLOAK_ENDPOINTS_ISSUER_DID}"
    [[ -n "${ISSUER_ENDPOINTS_BACKEND:-}" ]] && export ISSUER_BACKEND_URL="${ISSUER_ENDPOINTS_BACKEND}"
    [[ -n "${ISSUER_ENDPOINTS_FRONTEND:-}" ]] && export ISSUER_FRONTEND_URL="${ISSUER_ENDPOINTS_FRONTEND}"
    [[ -n "${DEV_CLIENTS_TEST_CLIENT:-}" ]] && export TEST_CLIENT_URL="${DEV_CLIENTS_TEST_CLIENT}"
}
# -----------------------------------------------------------------------------
# Configuration Loading
# -----------------------------------------------------------------------------
load_configuration() {
    local config_file="$WORK_DIR/config.yaml"
    local override_file="$WORK_DIR/config.override.yaml"
    local yq_files=("$config_file")

    # Check if config.yaml exists
    if [[ ! -f "$config_file" ]]; then
        error "config.yaml not found. Configuration file is required."
        return 1
    fi

    log "Loading configuration from $config_file"

    # Apply overrides from config.override.yaml if it exists
    if [[ -f "$override_file" ]]; then
        log "Applying overrides from $override_file"
        yq_files+=("$override_file")
    fi

    # Export variables using the new helper function.
    # The yq dependency check is now handled inside export_yaml_as_env.
    export_yaml_as_env "${yq_files[@]}"

    # -------------------------------------------------------------------------
    # Backward-compatible aliases for env placeholders used by realm configs
    # Map values from keycloak_endpoints/issuer_endpoints/dev_clients to expected placeholder names
    # -------------------------------------------------------------------------
    [[ -n "${DEV_CLIENTS_TEST_CLIENT:-}" ]] && export TEST_CLIENT_URL="${DEV_CLIENTS_TEST_CLIENT}"
    [[ -n "${ISSUER_ENDPOINTS_BACKEND:-}" ]] && export ISSUER_BACKEND_URL="${ISSUER_ENDPOINTS_BACKEND}"
    [[ -n "${ISSUER_ENDPOINTS_FRONTEND:-}" ]] && export ISSUER_FRONTEND_URL="${ISSUER_ENDPOINTS_FRONTEND}"
    [[ -n "${KEYCLOAK_ENDPOINTS_ISSUER_DID:-}" ]] && export ISSUER_DID="${KEYCLOAK_ENDPOINTS_ISSUER_DID}"
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

    # Export shorthand variables for convenience, as used in config.yaml
    export TARGET_DIR="${PROJECT_TARGET_DIR}"
    export TOOLS_DIR="${PROJECT_TOOLS_DIR}"

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
export -f urlencode detect_docker_compose init_script ensure_directory_exists check_dependencies export_yaml_as_env

