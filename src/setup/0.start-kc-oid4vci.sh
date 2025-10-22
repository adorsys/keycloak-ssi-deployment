#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Start Keycloak with OID4VCI
# - Stops any running instance
# - Prepares Keycloak via setup script
# - Starts DB container if needed
# - Injects providers and starts Keycloak
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-$PWD}"

# Load environment variables
source "$WORK_DIR/load_env.sh"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Stop any running Keycloak instance
# ---------------------------------------------------------------------------
log "Checking for running Keycloak instance..."
OS=$(uname -s)
case "$OS" in
    Linux*|Darwin*)
        keycloak_pid=$(pgrep -f keycloak || true)
        if [[ -n "$keycloak_pid" ]]; then
            log "Keycloak instance found (PID: $keycloak_pid). Shutting it down..."
            kill "$keycloak_pid" || warn "Failed to kill process $keycloak_pid"
        else
            log "No running Keycloak instance found."
        fi
        ;;
    *)
        warn "This script supports only Linux or macOS."
        ;;
esac

# ---------------------------------------------------------------------------
# Setup Keycloak (download/build/unpack, prepare keystore)
# ---------------------------------------------------------------------------
log "Preparing Keycloak..."
"$WORK_DIR/src/setup/setup-kc-oid4vci.sh"

# ---------------------------------------------------------------------------
# Detect Docker Compose command
# ---------------------------------------------------------------------------
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_COMMAND="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_COMMAND="docker-compose"
else
    error "Neither 'docker compose' (v2) nor 'docker-compose' (v1) is installed."
fi
log "Docker Compose detected: $DOCKER_COMPOSE_COMMAND"

# ---------------------------------------------------------------------------
# Start database container if not using manual KC_DB_OPTS
# ---------------------------------------------------------------------------
DOCKER_COMPOSE_FILE="${WORK_DIR}/docker-compose.yml"

if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
    error "docker-compose.yml not found in project root: $DOCKER_COMPOSE_FILE"
fi

if [[ -z "${KC_DB_OPTS:-}" ]]; then
    log "Starting database container using Docker Compose..."
    # Use eval to properly handle multi-word commands
    eval $DOCKER_COMPOSE_COMMAND -f "$DOCKER_COMPOSE_FILE" up -d db || error "Could not start database container"
    KC_DB_OPTS="--db postgres --db-url-port $KC_DB_EXPOSED_PORT --db-url-database $KC_DB_NAME --db-username $KC_DB_USERNAME --db-password $KC_DB_PASSWORD"
    log "Database container started and KC_DB_OPTS set."
else
    log "Using provided KC_DB_OPTS: $KC_DB_OPTS"
fi

# ---------------------------------------------------------------------------
# Inject providers
# ---------------------------------------------------------------------------
log "Injecting Keycloak providers..."
mkdir -p "$KC_INSTALL_DIR/providers"
cp "$WORK_DIR/providers/"*.jar "$KC_INSTALL_DIR/providers"

# ---------------------------------------------------------------------------
# Start Keycloak
# ---------------------------------------------------------------------------
log "Starting Keycloak with OID4VCI features..."
(
    export KC_BOOTSTRAP_ADMIN_USERNAME KC_BOOTSTRAP_ADMIN_PASSWORD
    cd "$KC_INSTALL_DIR" || error "Cannot cd to $KC_INSTALL_DIR"
    eval bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci,oid4vc-vpauth &
)
log "Keycloak startup initiated."
