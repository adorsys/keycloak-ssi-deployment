#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Color codes
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()     { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; exit 1; }
success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"; }

# -----------------------------------------------------------------------------
# Source common env variables
# -----------------------------------------------------------------------------
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$WORK_DIR/load_env.sh"

# -----------------------------------------------------------------------------
# Get admin token using environment variables for credentials
# -----------------------------------------------------------------------------
log "Obtaining admin token..."
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD
success "Admin token obtained."

# -----------------------------------------------------------------------------
# Read the direct access property of the openid4vc-rest-api client
# -----------------------------------------------------------------------------
log "Reading direct access property of the openid4vc-rest-api client..."
$KC_INSTALL_DIR/bin/kcadm.sh get clients -r $KEYCLOAK_REALM -q clientId=openid4vc-rest-api --fields 'id,directAccessGrantsEnabled'

# -----------------------------------------------------------------------------
# Store property ACC_CLIENT_ID in an environment variable
# -----------------------------------------------------------------------------
export ACC_CLIENT_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get clients -r $KEYCLOAK_REALM -q clientId=openid4vc-rest-api --fields id | jq -r '.[0].id')
log "Stored openid4vc-rest-api Client ID: $ACC_CLIENT_ID"

# -----------------------------------------------------------------------------
# Enable direct grant on the openid4vc-rest-api client
# -----------------------------------------------------------------------------
log "Enabling direct grant on the openid4vc-rest-api client..."
$KC_INSTALL_DIR/bin/kcadm.sh update clients/$ACC_CLIENT_ID -r $KEYCLOAK_REALM -s directAccessGrantsEnabled=true -o --fields 'id,directAccessGrantsEnabled'
success "Direct grant enabled."

# -----------------------------------------------------------------------------
# Create a user named Francis
# -----------------------------------------------------------------------------
log "Creating user Francis..."
$KC_INSTALL_DIR/bin/kcadm.sh create users -r $KEYCLOAK_REALM -s username=francis -s firstName=Francis -s lastName=Pouatcha -s email=fpo@mail.de -s enabled=true
success "User Francis created."

# -----------------------------------------------------------------------------
# Set password for Francis
# -----------------------------------------------------------------------------
log "Setting password for user Francis..."
$KC_INSTALL_DIR/bin/kcadm.sh set-password -r $KEYCLOAK_REALM --username $USER_FRANCIS_NAME --new-password $USER_FRANCIS_PASSWORD
success "Password set for Francis."

# -----------------------------------------------------------------------------
# Prepare user key proof header if not existent
# -----------------------------------------------------------------------------
if [ ! -f "./src/config/user_key_proof_header.json" ]; then
  log "Generating keypair for user..."
  ./src/utils/crypto/generate_user_key.sh
  success "User keyproof generated."
fi

success "Script execution completed."
