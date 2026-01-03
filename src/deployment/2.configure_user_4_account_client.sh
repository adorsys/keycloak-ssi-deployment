#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Helpers and env
# -----------------------------------------------------------------------------
# WORK_DIR is set by the CLI
source "$WORK_DIR/src/utils/helper.sh"
init_script

# -----------------------------------------------------------------------------
# Get admin token using environment variables for credentials
# -----------------------------------------------------------------------------
log "Obtaining admin token..."
keycloak_pid="$(get_keycloak_pid || true)"

# Run command function is used so 
if [[ "$keycloak_pid" == "docker:"* ]]; then
    CONTAINER_ID="${keycloak_pid#docker:}"
    KCADM_CMD=(docker exec -i $CONTAINER_ID /opt/keycloak/target/tools/keycloak-$KEYCLOAK_VERSION/bin/kcadm.sh)
    CONTAINER_TRUSTSTORE="/opt/keycloak/target/cacerts"
    
    "${KCADM_CMD[@]}" config truststore --trustpass "$SSL_TRUST_STORE_PASS" "$CONTAINER_TRUSTSTORE"
    "${KCADM_CMD[@]}" config credentials --server "$KEYCLOAK_ADMIN_ADDR" --realm master --user "$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" --password "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"
else
    KCADM="$KEYCLOAK_INSTALL_DIR/bin/kcadm.sh"
    KCADM_CMD=("$KCADM")
    "${KCADM_CMD[@]}" config truststore --trustpass "$SSL_TRUST_STORE_PASS" "$SSL_TRUST_STORE"
    "${KCADM_CMD[@]}" config credentials --server "$KEYCLOAK_ADMIN_ADDR" --realm master --user "$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" --password "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"
fi
success "Admin token obtained."

# -----------------------------------------------------------------------------
# Read the direct access property of the openid4vc-rest-api client
# -----------------------------------------------------------------------------
log "Reading direct access property of the openid4vc-rest-api client..."
"${KCADM_CMD[@]}" get clients -r "$KEYCLOAK_REALM" -q clientId=openid4vc-rest-api --fields 'id,directAccessGrantsEnabled' || true

# -----------------------------------------------------------------------------
# Store property ACC_CLIENT_ID in an environment variable
# -----------------------------------------------------------------------------
export ACC_CLIENT_ID=$("${KCADM_CMD[@]}" get clients -r "$KEYCLOAK_REALM" -q clientId=openid4vc-rest-api --fields id | jq -r '.[0].id')
log "Stored openid4vc-rest-api Client ID: $ACC_CLIENT_ID"

# -----------------------------------------------------------------------------
# Enable direct grant on the openid4vc-rest-api client
# -----------------------------------------------------------------------------
log "Enabling direct grant on the openid4vc-rest-api client..."
"${KCADM_CMD[@]}" update clients/$ACC_CLIENT_ID -r "$KEYCLOAK_REALM" -s directAccessGrantsEnabled=true -o --fields 'id,directAccessGrantsEnabled' || true
success "Direct grant enabled."

# -----------------------------------------------------------------------------
# Create a user named Francis
# -----------------------------------------------------------------------------
log "Creating user Francis if not exists..."
if ! "${KCADM_CMD[@]}" get users -r "$KEYCLOAK_REALM" -q username=francis | jq -e '.[0].id' >/dev/null 2>&1; then
  "${KCADM_CMD[@]}" create users -r "$KEYCLOAK_REALM" -s username=francis -s firstName=Francis -s lastName=Pouatcha -s email=fpo@mail.de -s enabled=true
  success "User Francis created."
else
  warn "User Francis already exists."
fi

# -----------------------------------------------------------------------------
# Set password for Francis
# -----------------------------------------------------------------------------
log "Setting password for user Francis..."
"${KCADM_CMD[@]}" set-password -r "$KEYCLOAK_REALM" --username "$USERS_FRANCIS_NAME" --new-password "$USERS_FRANCIS_PASSWORD" || true
success "Password ensured for Francis."

# -----------------------------------------------------------------------------
# Prepare user key proof header if not existent
# -----------------------------------------------------------------------------
if [ ! -f "$PROJECT_TARGET_DIR/user_key_proof_header.json" ]; then
  log "Generating keypair for user..."
  . "$WORK_DIR/src/utils/crypto/generate_user_key.sh"
  success "User keyproof generated."
else
  warn "User key proof header already exists."
fi

success "Script execution completed."
