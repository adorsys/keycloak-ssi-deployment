#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Stop any running Keycloak instance
# -----------------------------------------------------------------------------

OS=$(uname -s)
log() { echo -e "[INFO] $*"; }

case "$OS" in
    Linux*|Darwin*)
        keycloak_pid=$(pgrep -f keycloak || true)
        if [[ -n "$keycloak_pid" ]]; then
            log "Keycloak instance found (PID: $keycloak_pid). Shutting it down..."
            kill "$keycloak_pid"
        else
            log "No running Keycloak instance found."
        fi
        ;;
    *)
        echo "Unsupported OS: $OS. This script only supports Linux or macOS." >&2
        exit 1
        ;;
esac
