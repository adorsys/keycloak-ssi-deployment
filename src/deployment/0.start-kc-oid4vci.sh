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

# Load helpers (init_script loads env)
source "$WORK_DIR/src/utils/helper.sh"
init_script

# ---------------------------------------------------------------------------
# Stop any running Keycloak instance
# ---------------------------------------------------------------------------
log "Checking for running Keycloak instance..."
stop_keycloak
log "Keycloak stop process completed."
log "Continuing with script execution..."

# ---------------------------------------------------------------------------
# Setup Keycloak (download/build/unpack, prepare keystore)
# ---------------------------------------------------------------------------
log "Preparing Keycloak..."
"$WORK_DIR/src/deployment/setup-kc-oid4vci.sh"

# ---------------------------------------------------------------------------
# Detect Docker Compose command
# ---------------------------------------------------------------------------
DOCKER_COMPOSE_COMMAND="$(detect_docker_compose)"
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
# Start Keycloak (foreground by default; '-d' to detach and log to file)
# ---------------------------------------------------------------------------

DETACH_MODE="false"
if [[ "${1:-}" == "-d" ]]; then
  DETACH_MODE="true"
fi

log "Starting Keycloak with OID4VCI features..."
export KC_BOOTSTRAP_ADMIN_USERNAME KC_BOOTSTRAP_ADMIN_PASSWORD
cd "$KC_INSTALL_DIR" || error "Cannot cd to $KC_INSTALL_DIR"

if [[ "$DETACH_MODE" == "true" ]]; then
  LOG_DIR="$WORK_DIR/target"
  ensure_directory_exists "$LOG_DIR"
  LOG_FILE="$LOG_DIR/keycloak.log"
  log "Detaching Keycloak; logs will be written to $LOG_FILE"
  nohup bash -c "exec bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci,oid4vc-vpauth" \
    >"$LOG_FILE" 2>&1 &
  disown || true
else
  bash -c "exec bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci,oid4vc-vpauth"
fi
