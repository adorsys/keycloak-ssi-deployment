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
log()     { printf "\n${CYAN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "\n${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
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
        # Find the project root by looking for load_env.sh
        local search_dir="${PWD}"
        while [[ "$search_dir" != "/" && "$search_dir" != "" ]]; do
            if [[ -f "$search_dir/load_env.sh" ]]; then
                WORK_DIR="$search_dir"
                break
            fi
            search_dir="$(dirname "$search_dir")"
        done
        
        if [[ -z "${WORK_DIR:-}" ]]; then
            error "Could not find project root containing load_env.sh"
        fi
    fi
    
    # Load environment variables
    if [[ -f "$WORK_DIR/load_env.sh" ]]; then
        source "$WORK_DIR/load_env.sh"
    else
        error "load_env.sh not found in $WORK_DIR"
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
# Script Initialization
# -----------------------------------------------------------------------------
init_script() {
    # Always load environment variables if WORK_DIR is set
    if [[ -n "${WORK_DIR:-}" ]]; then
        if [[ -f "$WORK_DIR/load_env.sh" ]]; then
            source "$WORK_DIR/load_env.sh"
        fi
    else
        # Setup environment only if WORK_DIR is not already set
        setup_environment
    fi
    
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
export -f urlencode detect_docker_compose init_script ensure_directory_exists
