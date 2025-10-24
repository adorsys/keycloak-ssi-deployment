#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# OID4VCI test deployment script
# - Ensures Keycloak is running
# - Creates realm, registers key providers and clients
# - Configures client scopes, SAML IdP, and validates OID4VCI config
# -----------------------------------------------------------------------------

# Use standardized helper
WORK_DIR="${WORK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$WORK_DIR/src/utils/helper.sh"
init_script

# -----------------------------------------------------------------------------
# Ensure Keycloak is running
# Use helper's get_keycloak_pid
# -----------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Ensure Keycloak is running
# Use helper's get_keycloak_pid
# ---------------------------------------------------------------------------
keycloak_pid="$(get_keycloak_pid || true)"
if [[ -z "${keycloak_pid:-}" ]]; then
  error "Keycloak not running. Start Keycloak using '0.start-kc-oid4vci.sh' first."
fi
log "Keycloak is running with PID: $keycloak_pid"

# ---------------------------------------------------------------------------
# Helper for executing kcadm
# ---------------------------------------------------------------------------
KCADM="$KC_INSTALL_DIR/bin/kcadm.sh"
if [[ ! -x "$KCADM" ]]; then
  error "kcadm.sh not found or not executable at $KCADM"
fi

# ---------------------------------------------------------------------------
# Authenticate admin
# ---------------------------------------------------------------------------
log "Obtaining admin token / configuring kcadm..."
"$KCADM" config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE"
"$KCADM" config credentials --server "$KEYCLOAK_ADMIN_ADDR" --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"

# ---------------------------------------------------------------------------
# Create realm (idempotent)
# ---------------------------------------------------------------------------
log "Creating realm '$KEYCLOAK_REALM' (if not exists)..."
"$KCADM" create realms -s realm="$KEYCLOAK_REALM" -s enabled=true 2>/dev/null || log "Realm may already exist; continuing."

# ---------------------------------------------------------------------------
# Configure key providers (idempotent)
# ---------------------------------------------------------------------------
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

  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
     --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
     --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
     --arg keyAlias "$alias" \
     --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
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
  exists=$("$KCADM" get components -r "$KEYCLOAK_REALM" --fields name | jq -r --arg n "$name" '.[]? | select(.name == $n) | .id' | head -n1)
  if [[ -n "$exists" ]]; then
    log "Key provider '$name' already exists (ID: $exists). Skipping creation."
    return 0
  fi

  echo "$json_content" | "$KCADM" create components -r "$KEYCLOAK_REALM" -o -f - && \
    success "Registered key provider '$name' successfully." || \
    warn "Failed to register key provider '$name' (continuing)."
}

# ECDSA
if [[ -f "$ECDSA_JSON" ]]; then
  log "Ensuring ECDSA provider exists..."
  ECDSA_PROVIDER_JSON=$(configure_key_provider "$ECDSA_JSON" "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS")
  NAME=$(jq -r '.name' "$ECDSA_JSON")
  register_key_provider "$NAME" "$ECDSA_PROVIDER_JSON"
fi

# RSA Signing
if [[ -f "$RSA_JSON" ]]; then
  log "Ensuring RSA signing provider exists..."
  RSA_PROVIDER_JSON=$(configure_key_provider "$RSA_JSON" "$KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS")
  NAME=$(jq -r '.name' "$RSA_JSON")
  register_key_provider "$NAME" "$RSA_PROVIDER_JSON"
fi

# RSA Encryption
if [[ -f "$RSA_ENC_JSON" ]]; then
  log "Ensuring RSA encryption provider exists..."
  RSA_ENC_PROVIDER_JSON=$(configure_key_provider "$RSA_ENC_JSON" "$KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS")
  NAME=$(jq -r '.name' "$RSA_ENC_JSON")
  register_key_provider "$NAME" "$RSA_ENC_PROVIDER_JSON"
fi

# ---------------------------------------------------------------------------
# Disable built-in keys
# ---------------------------------------------------------------------------
log "Disabling generated built-in provider keys if present..."
RSA_OAEP_KID=$("$KCADM" get keys -r "$KEYCLOAK_REALM" --fields 'active(RSA-OAEP)' | jq -r '.active."RSA-OAEP" // empty')
if [[ -n "$RSA_OAEP_KID" ]]; then
  RSA_OAEP_PROV_ID=$("$KCADM" get keys -r "$KEYCLOAK_REALM" | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
  if [[ -n "$RSA_OAEP_PROV_ID" ]]; then
    "$KCADM" update components/"$RSA_OAEP_PROV_ID" -r "$KEYCLOAK_REALM" -s 'config.active=["false"]' || warn "Failed to deactivate RSA-OAEP provider"
  fi
fi

RS256_KID=$("$KCADM" get keys -r "$KEYCLOAK_REALM" --fields 'active(RS256)' | jq -r '.active.RS256 // empty')
if [[ -n "$RS256_KID" ]]; then
  RS256_PROV_ID=$("$KCADM" get keys -r "$KEYCLOAK_REALM" | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
  if [[ -n "$RS256_PROV_ID" ]]; then
    "$KCADM" update components/"$RS256_PROV_ID" -r "$KEYCLOAK_REALM" -s 'config.active=["false"]' || warn "Failed to deactivate RS256 provider"
  fi
fi

# ---------------------------------------------------------------------------
# Update realm attributes
# ---------------------------------------------------------------------------
log "Updating realm attributes..."
if [[ -f "$WORK_DIR/src/config/realm-attributes.json" ]]; then
  cat "$WORK_DIR/src/config/realm-attributes.json" | "$KCADM" update realms/"$KEYCLOAK_REALM" -o -f - || error "Realm update failed"
else
  warn "realm-attributes.json not found; skipping realm attribute update."
fi

# ---------------------------------------------------------------------------
# Create client scopes
# ---------------------------------------------------------------------------
log "Creating client scopes..."
if [[ -f "$WORK_DIR/src/config/client-scope-config.json" ]]; then
  CLIENT_SCOPES_CONFIG=$(jq --arg ISSUER_DID "$ISSUER_DID" 'map(.attributes["vc.issuer_did"] = $ISSUER_DID)' "$WORK_DIR/src/config/client-scope-config.json")
  echo "$CLIENT_SCOPES_CONFIG" | jq -c '.[]' | while read -r scope; do
    echo "$scope" | "$KCADM" create client-scopes -r "$KEYCLOAK_REALM" -f - 2>/dev/null || warn "Client scope creation may already exist"
  done
else
  warn "client-scope-config.json not found; skipping client scopes."
fi

# ---------------------------------------------------------------------------
# SAML Identity Provider and mappers
# ---------------------------------------------------------------------------
log "Creating SAML Identity Provider..."
if [[ -f "$WORK_DIR/src/config/saml-idp-config.json" ]]; then
  SAML_IDP_CONFIG=$(jq --arg ENTITY_ID "$ISSUER_DID" '.identityProviders |= map(.config.entityId = $ENTITY_ID)' "$WORK_DIR/src/config/saml-idp-config.json")
  echo "$SAML_IDP_CONFIG" | jq -c '.identityProviders[]' | while read -r idp; do
    echo "$idp" | "$KCADM" create identity-provider/instances -r "$KEYCLOAK_REALM" -f - 2>/dev/null || warn "SAML Identity Provider creation may already exist"
  done

  log "Creating SAML Identity Provider Mappers..."
  echo "$SAML_IDP_CONFIG" | jq -c '.identityProviderMappers[]' | while read -r mapper; do
    echo "$mapper" | "$KCADM" create identity-provider/instances/saml/mappers -r "$KEYCLOAK_REALM" -f - 2>/dev/null || warn "SAML IdP mapper creation may already exist"
  done
else
  warn "saml-idp-config.json not found; skipping SAML IdP creation."
fi

# ---------------------------------------------------------------------------
# Create clients
# ---------------------------------------------------------------------------
log "Creating OPENID4VC-REST-API client..."
if [[ -f "$WORK_DIR/src/config/openid4vc-rest-api.json" ]]; then
  CONFIG=$(jq --arg CLIENT_SECRET "$CLIENT_SECRET" \
               --arg ISSUER_BACKEND_URL "$ISSUER_BACKEND_URL" \
               --arg ISSUER_FRONTEND_URL "$ISSUER_FRONTEND_URL" \
               '.secret += $CLIENT_SECRET |
                .redirectUris += [$ISSUER_BACKEND_URL + "/*", ($ISSUER_BACKEND_URL + "/callback")] |
                .webOrigins += [$ISSUER_BACKEND_URL] |
                .attributes["post.logout.redirect.uris"] = ($ISSUER_FRONTEND_URL + "##" + $ISSUER_FRONTEND_URL + "/*")' \
               "$WORK_DIR/src/config/openid4vc-rest-api.json")
  echo "$CONFIG" | "$KCADM" create clients -r "$KEYCLOAK_REALM" -o -f - 2>/dev/null || warn "OPENID4VC-REST-API client creation may already exist"
else
  warn "openid4vc-rest-api.json not found; skipping client creation."
fi

log "Creating oid4vc-demo-public client..."
if [[ -f "$WORK_DIR/src/config/oid4vc-demo-public.json" ]]; then
  PUBLIC_CLIENT=$(jq --arg TEST_CLIENT_URL "$TEST_CLIENT_URL" \
                     '.rootUrl = $TEST_CLIENT_URL | .baseUrl = $TEST_CLIENT_URL | .redirectUris = [$TEST_CLIENT_URL + "/*"] | .webOrigins = [$TEST_CLIENT_URL] | .attributes["post.logout.redirect.uris"] = ($TEST_CLIENT_URL + "##" + $TEST_CLIENT_URL + "/*")' \
                     "$WORK_DIR/src/config/oid4vc-demo-public.json")
  echo "$PUBLIC_CLIENT" | "$KCADM" create clients -r "$KEYCLOAK_REALM" -o -f - 2>/dev/null || warn "oid4vc-demo-public client may already exist"
else
  warn "oid4vc-demo-public.json not found; skipping public client creation."
fi

# ---------------------------------------------------------------------------
# Ensure sd-jwt authenticator VCT
# ---------------------------------------------------------------------------
log "Ensuring sd-jwt authenticator VCT is configured..."
if [[ -f "$WORK_DIR/src/utils/update_sdjwt_vct.sh" ]]; then
  "$WORK_DIR/src/utils/update_sdjwt_vct.sh" || warn "SD-JWT VCT update failed (non-critical)."
else
  warn "update_sdjwt_vct.sh not found; skipping."
fi

# ---------------------------------------------------------------------------
# Validate OID4VCI configuration
# ---------------------------------------------------------------------------
log "Validating OID4VCI configuration exposure..."
response=$(curl -ks "$KEYCLOAK_ADMIN_ADDR/realms/$KEYCLOAK_REALM/.well-known/openid-credential-issuer")
if [[ -z "$response" ]]; then
  error "No response from Keycloak OIDC credential issuer endpoint."
fi

for credential in "SteuerberaterCredential" "IdentityCredential" "KMACredential"; do
  if ! jq -e --arg c "$credential" '."credential_configurations_supported"[$c]' <<< "$response" > /dev/null; then
    error "Server started but error occurred. '$credential' not found in OID4VCI configuration."
  fi
done

success "Keycloak server is running with OID4VCI feature and credentials configured."
log "Deployment script completed."
