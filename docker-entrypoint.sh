#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Ensure WORK_DIR is defined (default to runtime root)
WORK_DIR="${WORK_DIR:-/opt/keycloak}"

# Load helper (init_script loads env)
source "$WORK_DIR/src/utils/helper.sh"
init_script

# Start Keycloak
cd "$KEYCLOAK_INSTALL_DIR"
exec bin/kc.sh $START_COMMAND $DATABASE_OPTS --features=oid4vc-vci "$@"
