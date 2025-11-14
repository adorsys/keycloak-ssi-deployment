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

    # Load environment variables
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
    debug "DEBUG: Attempting to get Keycloak PID..."
    local pid
    if command -v pgrep &>/dev/null; then
        pid=$(pgrep -f keycloak | head -n1 || true)
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            pid=$(ps aux | grep -i '[q]uarkus' | awk 'NR==1{print $2}' || true)
        else
            pid=$(ps aux | grep -i '[k]eycloak' | awk 'NR==1{print $2}' || true)
        fi
    fi
    debug "DEBUG: get_keycloak_pid found PID: $pid"
    echo "$pid"
}

stop_keycloak() {
    debug "DEBUG: stop_keycloak function called."
    local keycloak_pid
    keycloak_pid="$(get_keycloak_pid || true)"

    if [[ -n "$keycloak_pid" ]]; then
        log "Keycloak instance found (PID: $keycloak_pid). Shutting it down..."
        kill "$keycloak_pid" || warn "Failed to kill process $keycloak_pid. It might already be stopped or require elevated privileges."
        # Wait for process to terminate
        sleep 2
        if kill -0 "$keycloak_pid" 2>/dev/null; then
            warn "Process $keycloak_pid still running after SIGTERM, force killing with SIGKILL..."
            kill -9 "$keycloak_pid" 2>/dev/null || true
            sleep 1
        fi
        if kill -0 "$keycloak_pid" 2>/dev/null; then
            error "Failed to stop Keycloak process $keycloak_pid even after SIGKILL."
        else
            log "Keycloak stopped."
        fi
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
    for dep in openssl keytool jq figlet; do
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
    script_name="$(basename "${BASH_SOURCE[1]}")"
    log "Starting $script_name"
}

# -----------------------------------------------------------------------------
# Export functions for use in other scripts
# -----------------------------------------------------------------------------
export -f log warn error success
export -f setup_environment get_keycloak_pid stop_keycloak
export -f urlencode detect_docker_compose init_script ensure_directory_exists check_dependencies
