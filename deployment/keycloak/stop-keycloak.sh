#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$PROJECT_ROOT/keycloak-oauth-sig/oid4vci-deployment"
export WORK_DIR

source "$WORK_DIR/src/utils/helper.sh"
init_script

KEYCLOAK_ONLY=false
if [[ "${1:-}" == "--keycloak-only" ]]; then
    KEYCLOAK_ONLY=true
fi

stop_keycloak_process() {
    local keycloak_pid
    local stopped=false

    while IFS= read -r keycloak_pid || [[ -n "$keycloak_pid" ]]; do
        [[ -z "$keycloak_pid" ]] && continue
        stopped=true
        log "Stopping Keycloak process $keycloak_pid..."
        kill "$keycloak_pid" 2>/dev/null || true

        local attempt
        for attempt in {1..30}; do
            if ! kill -0 "$keycloak_pid" 2>/dev/null; then
                break
            fi
            sleep 1
        done

        if kill -0 "$keycloak_pid" 2>/dev/null; then
            warn "Keycloak did not stop gracefully; terminating process $keycloak_pid."
            kill -9 "$keycloak_pid" 2>/dev/null || true
        fi
    done < <(get_keycloak_pid || true)

    rm -f "$WORK_DIR/target/keycloak.pid"
    if [[ "$stopped" == "false" ]]; then
        log "No running Keycloak process found."
    fi
}

stop_keycloak_process

if [[ "$KEYCLOAK_ONLY" == "false" ]]; then
    compose_command="$(detect_docker_compose)"
    IFS=' ' read -r -a compose_args <<< "$compose_command"
    log "Stopping the database container while preserving its volume..."
    "${compose_args[@]}" -f "$WORK_DIR/docker-compose.yml" stop db || \
        warn "The database container could not be stopped."
fi
