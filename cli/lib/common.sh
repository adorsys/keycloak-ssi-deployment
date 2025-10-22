#!/bin/bash
#
# Common functions for Keycloak SSI CLI
#

# Path definitions
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLI_ROOT="$(dirname "$SCRIPT_DIR")"
export PROJECT_ROOT="$(dirname "$CLI_ROOT")"
export SCRIPTS_DIR="$PROJECT_ROOT/scripts"
export CONFIG_DIR="$PROJECT_ROOT/config"
export ASSETS_DIR="$PROJECT_ROOT/assets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()
    
    for tool in openssl keytool jq curl docker; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
}

# Load environment variables
# Source common environment variables
. ../../scripts/utils/load_env.sh

# Validate environment
validate_env() {
    local required_vars=(
        "KEYCLOAK_URL"
        "KC_BOOTSTRAP_ADMIN_USERNAME"
        "KC_BOOTSTRAP_ADMIN_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
}

# Check if Keycloak is running
check_keycloak_running() {
    if pgrep -f "keycloak" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for Keycloak to be ready
wait_for_keycloak() {
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for Keycloak to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if check_keycloak_running; then
            log_success "Keycloak is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for Keycloak..."
        sleep 5
        ((attempt++))
    done
    
    log_error "Keycloak failed to start within expected time"
    exit 1
}

# Get admin token
get_admin_token() {
    local token_url="$KEYCLOAK_URL/realms/master/protocol/openid-connect/token"
    
    curl -k -s -X POST "$token_url" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KC_BOOTSTRAP_ADMIN_USERNAME" \
        -d "password=$KC_BOOTSTRAP_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token'
}

# Execute kcadm command
kcadm() {
    local kc_install_dir="${KC_INSTALL_DIR:-$PROJECT_ROOT/tools/keycloak}"
    local kcadm_path="$kc_install_dir/bin/kcadm.sh"
    
    if [ ! -f "$kcadm_path" ]; then
        log_error "Keycloak admin CLI not found at $kcadm_path"
        exit 1
    fi
    
    "$kcadm_path" "$@"
}

# Show progress indicator
show_progress() {
    local pid=$1
    local message=$2
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}$message${NC} ["
        for i in {1..3}; do
            printf "."
            sleep 0.5
        done
        printf "]"
        sleep 0.5
    done
    printf "\r${GREEN}$message completed${NC}\n"
}
