#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$PROJECT_ROOT/keycloak-oauth-sig/oid4vci-deployment"
export WORK_DIR

source "$WORK_DIR/src/utils/helper.sh"
init_script

DETACH_MODE=false
if [[ "${1:-}" == "-d" || "${1:-}" == "--detach" ]]; then
    DETACH_MODE=true
fi

# Stop only the Keycloak process. The database must survive restarts so that
# Keycloak can migrate the existing schema and retain configured realms.
"$SCRIPT_DIR/stop-keycloak.sh" --keycloak-only

log "Preparing Keycloak $KEYCLOAK_VERSION from the upstream distribution..."
"$WORK_DIR/src/deployment/setup-kc-oid4vci.sh"

compose_command="$(detect_docker_compose)"
IFS=' ' read -r -a compose_args <<< "$compose_command"

if [[ -z "${DATABASE_OPTS:-}" ]]; then
    log "Starting the existing database container..."
    "${compose_args[@]}" -f "$WORK_DIR/docker-compose.yml" up -d db || \
        error "Could not start the database container."
    DATABASE_OPTS="--db postgres --db-url-port $DATABASE_EXPOSED_PORT --db-url-database $DATABASE_NAME --db-username $DATABASE_USERNAME --db-password $DATABASE_PASSWORD"
fi

if [[ -z "${KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME:-}" || -z "${KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD:-}" ]]; then
    error "Bootstrap admin credentials are missing. Configure keycloak.bootstrap in config-override.yaml."
fi

log "Installing SSI-managed Keycloak providers..."
mkdir -p "$KEYCLOAK_INSTALL_DIR/providers"
provider_count=0
for provider in "$PROJECT_ROOT"/providers/*.jar; do
    [[ -f "$provider" ]] || continue
    cp "$provider" "$KEYCLOAK_INSTALL_DIR/providers/"
    provider_count=$((provider_count + 1))
done
if [[ "$provider_count" -eq 0 ]]; then
    error "No provider JARs found in $PROJECT_ROOT/providers."
fi

IFS=' ' read -r -a database_args <<< "$DATABASE_OPTS"
IFS=' ' read -r -a start_args <<< "$START_COMMAND"
migration_args=()
if [[ -n "${DATABASE_MIGRATION_STRATEGY:-}" ]]; then
    migration_args+=("--spi-connections-jpa-quarkus-migration-strategy=$DATABASE_MIGRATION_STRATEGY")
fi

cd "$KEYCLOAK_INSTALL_DIR"

log "Ensuring the bootstrap admin exists and migrating the database when required..."
bootstrap_status=0
bootstrap_output="$(bin/kc.sh bootstrap-admin user \
    --username "$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" \
    --password:env KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD \
    "${database_args[@]}" "${migration_args[@]}" 2>&1)" || bootstrap_status=$?

if [[ "$bootstrap_status" -ne 0 ]]; then
    if grep -Eqi "user with username.*exists|duplicate key value" <<< "$bootstrap_output"; then
        log "Bootstrap admin already exists; continuing."
    else
        printf '%s\n' "$bootstrap_output" >&2
        error "Failed to bootstrap the Keycloak administrator."
    fi
fi

export KC_BOOTSTRAP_ADMIN_USERNAME="$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME"
export KC_BOOTSTRAP_ADMIN_PASSWORD="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"

log_dir="$WORK_DIR/target"
mkdir -p "$log_dir"

log "Starting Keycloak with features: $KEYCLOAK_FEATURES"
if [[ "$DETACH_MODE" == "true" ]]; then
    log_file="$log_dir/keycloak.log"
    nohup bin/kc.sh "${start_args[@]}" "${database_args[@]}" \
        "${migration_args[@]}" "--features=$KEYCLOAK_FEATURES" \
        >"$log_file" 2>&1 &
    keycloak_pid=$!
    printf '%s\n' "$keycloak_pid" > "$log_dir/keycloak.pid"
    disown "$keycloak_pid" 2>/dev/null || true
    log "Keycloak started as process $keycloak_pid; logs: $log_file"
else
    printf '%s\n' "$$" > "$log_dir/keycloak.pid"
    exec bin/kc.sh "${start_args[@]}" "${database_args[@]}" \
        "${migration_args[@]}" "--features=$KEYCLOAK_FEATURES"
fi
