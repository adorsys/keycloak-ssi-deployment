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
    
    # Determine work directory
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    WORK_DIR="${WORK_DIR:-$(cd "$script_dir/../.." && pwd)}"
    
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
        # Check if process is still running
        if kill -0 "$keycloak_pid" 2>/dev/null; then
            warn "Process still running, force killing..."
            kill -9 "$keycloak_pid" 2>/dev/null || true
            sleep 1
        fi
    else
        log "No running Keycloak instance found."
    fi
}


# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------
urlencode() {
    jq -nr --arg str "$1" '$str|@uri'
}

ensure_directory_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log "Directory $dir does not exist. Creating..."
        mkdir -p "$dir" || error "Failed to create $dir"
        log "Directory $dir created."
    else
        debug "Directory $dir already exists."
    fi
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
# PKCE Generation
# -----------------------------------------------------------------------------
generate_pkce() {
    local code_verifier
    code_verifier=$(openssl rand -base64 96 | tr -d '+/=' | cut -c -128)
    local code_challenge
    code_challenge=$(echo -n "$code_verifier" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')
    echo "$code_verifier" "$code_challenge"
}


# -----------------------------------------------------------------------------
# Script Initialization
# -----------------------------------------------------------------------------
init_script() {
    # Setup environment
    setup_environment
    
    # Log script start
    local script_name
    script_name="$(basename "${BASH_SOURCE[1]}")"
    log "Starting $script_name"
}

# -----------------------------------------------------------------------------
# Export functions for use in other scripts
# -----------------------------------------------------------------------------
export -f log warn error success debug
export -f setup_environment get_keycloak_pid stop_keycloak
export -f urlencode ensure_directory_exists
export -f detect_docker_compose generate_pkce
export -f init_script
