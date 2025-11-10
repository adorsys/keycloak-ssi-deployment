#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# OID4VCI configuration script
# - Ensures Keycloak is running
# - Creates realm, registers key providers and clients
# - Configures client scopes, SAML IdP, and validates OID4VCI config
# -----------------------------------------------------------------------------

# WORK_DIR is set by the CLI
source "$WORK_DIR/src/utils/helper.sh"
init_script

# -----------------------------------------------------------------------------
# Ensure Keycloak is running
# -----------------------------------------------------------------------------
keycloak_pid="$(get_keycloak_pid || true)"
if [[ -z "${keycloak_pid:-}" ]]; then
  error "Keycloak is not running. Start Keycloak using '0.start-kc-oid4vci.sh' first."
fi
log "Keycloak is running (PID: $keycloak_pid)."

# -----------------------------------------------------------------------------
# Helper for executing kcadm
# -----------------------------------------------------------------------------
KCADM="$KEYCLOAK_INSTALL_DIR/bin/kcadm.sh"
if [[ ! -x "$KCADM" ]]; then
  error "kcadm.sh not found or not executable at: $KCADM"
fi

# -----------------------------------------------------------------------------
# Authenticate admin
# -----------------------------------------------------------------------------
log "Authenticating admin user..."
"$KCADM" config truststore --trustpass "$SSL_TRUST_STORE_PASS" "$SSL_TRUST_STORE"
"$KCADM" config credentials --server "$URLS_ADMIN_ADDR" --realm master \
    --user "$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" --password "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"

# -----------------------------------------------------------------------------
# Create realm
# -----------------------------------------------------------------------------
log "Creating realm '$KEYCLOAK_REALM' (if not exists)..."
"$KCADM" create realms -s realm="$KEYCLOAK_REALM" -s enabled=true >/dev/null 2>&1 || warn "Realm already exists; continuing."

# -----------------------------------------------------------------------------
# Configure key providers
# -----------------------------------------------------------------------------
log "Configuring key providers (ECDSA, RSA signing, RSA encryption)..."

ECDSA_JSON="$WORK_DIR/src/config/issuer_key_ecdsa.json"
RSA_JSON="$WORK_DIR/src/config/issuer_key_rsa.json"
RSA_ENC_JSON="$WORK_DIR/src/config/encryption_key_rsa.json"

configure_key_provider() {
  local json_template="$1"
  local alias="$2"

  if [[ ! -f "$json_template" ]]; then
    error "Key provider template not found: $json_template"
  fi

  jq --arg keystore "$KEYSTORE_FILE" \
     --arg keystorePassword "$KEYSTORE_PASSWORD" \
     --arg keystoreType "$KEYSTORE_TYPE" \
     --arg keyAlias "$alias" \
     --arg keyPassword "$KEYSTORE_PASSWORD" \
     '.config.keystore = [$keystore] |
      .config.keystorePassword = [$keystorePassword] |
      .config.keystoreType = [$keystoreType] |
      .config.keyAlias = [$keyAlias] |
      .config.keyPassword = [$keyPassword]' "$json_template"
}

register_key_provider() {
  local name="$1"
  local json_content="$2"

  local exists
  exists=$("$KCADM" get components -r "$KEYCLOAK_REALM" --fields name \
            | jq -r --arg n "$name" '.[]? | select(.name == $n) | .id' | head -n1)

  if [[ -n "$exists" ]]; then
    warn "Key provider '$name' already exists (ID: $exists); skipping."
    return 0
  fi

  if ! echo "$json_content" | "$KCADM" create components -r "$KEYCLOAK_REALM" -o -f - >/dev/null 2>&1; then
    warn "Failed to register key provider '$name'; it already exists."
  fi
}

# ECDSA
if [[ -f "$ECDSA_JSON" ]]; then
  ECDSA_PROVIDER_JSON=$(configure_key_provider "$ECDSA_JSON" "$KEYSTORE_ALIASES_ECDSA_KEY")
  NAME=$(jq -r '.name' "$ECDSA_JSON")
  register_key_provider "$NAME" "$ECDSA_PROVIDER_JSON"
fi

# RSA Signing
if [[ -f "$RSA_JSON" ]]; then
  RSA_PROVIDER_JSON=$(configure_key_provider "$RSA_JSON" "$KEYSTORE_ALIASES_RSA_SIG_KEY")
  NAME=$(jq -r '.name' "$RSA_JSON")
  register_key_provider "$NAME" "$RSA_PROVIDER_JSON"
fi

# RSA Encryption
if [[ -f "$RSA_ENC_JSON" ]]; then
  RSA_ENC_PROVIDER_JSON=$(configure_key_provider "$RSA_ENC_JSON" "$KEYSTORE_ALIASES_RSA_ENC_KEY")
  NAME=$(jq -r '.name' "$RSA_ENC_JSON")
  register_key_provider "$NAME" "$RSA_ENC_PROVIDER_JSON"
fi

log "Custom key provider registration complete."

# -----------------------------------------------------------------------------
# Update realm attributes
# -----------------------------------------------------------------------------
log "Updating realm attributes..."
if [[ -f "$WORK_DIR/src/config/realm-attributes.json" ]]; then
  cat "$WORK_DIR/src/config/realm-attributes.json" | "$KCADM" update realms/"$KEYCLOAK_REALM" -o -f - >/dev/null || error "Realm update failed"
else
  warn "realm-attributes.json not found; skipping realm attribute update."
fi

# -----------------------------------------------------------------------------
# Create client scopes
# -----------------------------------------------------------------------------
log "Creating client scopes..."
if [[ -f "$WORK_DIR/src/config/client-scope-config.json" ]]; then
  CLIENT_SCOPES_CONFIG=$(jq --arg ISSUER_DID "$URLS_ISSUER_DID" 'map(.attributes["vc.issuer_did"] = $ISSUER_DID)' "$WORK_DIR/src/config/client-scope-config.json")
  echo "$CLIENT_SCOPES_CONFIG" | jq -c '.[]' | while read -r scope; do
    echo "$scope" | "$KCADM" create client-scopes -r "$KEYCLOAK_REALM" -f - >/dev/null 2>&1 || \
      warn "Client scope already exists; skipping."
  done
else
  warn "client-scope-config.json not found; skipping client scopes creation."
fi

# -----------------------------------------------------------------------------
# Configure SAML Identity Provider
# -----------------------------------------------------------------------------
SAML_CONFIG_FILE="$WORK_DIR/src/config/saml-idp-config.json"
if [[ -f "$SAML_CONFIG_FILE" ]]; then
    jq -c '.identityProviders[]' "$SAML_CONFIG_FILE" | while read -r idp; do
        echo "$idp" | "$KCADM" create identity-provider/instances -r "$KEYCLOAK_REALM" -f - >/dev/null 2>&1 || \
          warn "SAML Identity Provider already exists; skipping."
    done

    if jq -e '.identityProviderMappers' "$SAML_CONFIG_FILE" >/dev/null 2>&1; then
        jq -c '.identityProviderMappers[]' "$SAML_CONFIG_FILE" | while read -r mapper; do
            echo "$mapper" | "$KCADM" create identity-provider/instances/saml/mappers -r "$KEYCLOAK_REALM" -f - >/dev/null 2>&1 || \
              warn "SAML mapper already exists: $(echo "$mapper" | jq -r '.name')"
        done
    fi
else
    warn "SAML configuration file not found; skipping SAML IdP configuration."
fi

# -----------------------------------------------------------------------------
# Create clients
# -----------------------------------------------------------------------------
log "Creating clients..."
[[ -f "$WORK_DIR/src/config/openid4vc-rest-api.json" ]] && \
  CONFIG=$(jq --arg CLIENT_SECRET "$CLIENTS_SECRET" \
               '.secret += $CLIENT_SECRET' \
               "$WORK_DIR/src/config/openid4vc-rest-api.json") && \
  echo "$CONFIG" | "$KCADM" create clients -r "$KEYCLOAK_REALM" -o -f - >/dev/null 2>&1 || \
  warn "OPENID4VC-REST-API client already exists; skipping."

[[ -f "$WORK_DIR/src/config/oid4vc-demo-public.json" ]] && \
  PUBLIC_CLIENT=$(jq '.' "$WORK_DIR/src/config/oid4vc-demo-public.json") && \
  echo "$PUBLIC_CLIENT" | "$KCADM" create clients -r "$KEYCLOAK_REALM" -o -f - >/dev/null 2>&1 || \
  warn "oid4vc-demo-public client already exists; skipping."

# -----------------------------------------------------------------------------
# Ensure SD-JWT authenticator VCT
# -----------------------------------------------------------------------------
log "Ensuring SD-JWT authenticator VCT is configured..."
[[ -f "$WORK_DIR/src/utils/update_sdjwt_vct.sh" ]] && \
  "$WORK_DIR/src/utils/update_sdjwt_vct.sh" >/dev/null 2>&1 || warn "SD-JWT VCT update failed or script missing; skipping."

# -----------------------------------------------------------------------------
# Validate OID4VCI configuration
# -----------------------------------------------------------------------------
log "Validating OID4VCI configuration..."
response=$(curl -ks "$URLS_ADMIN_ADDR/realms/$KEYCLOAK_REALM/.well-known/openid-credential-issuer")
[[ -z "$response" ]] && error "No response from Keycloak OIDC credential issuer endpoint."

for credential in "SteuerberaterCredential" "IdentityCredential" "KMACredential"; do
  jq -e --arg c "$credential" '."credential_configurations_supported"[$c]' <<< "$response" >/dev/null || \
    error "Configuration missing: '$credential' not found in OID4VCI configuration."
done

success "Keycloak server is running and OID4VCI credentials are configured successfully."
log "Configuration script completed successfully."


