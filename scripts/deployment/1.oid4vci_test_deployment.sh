#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 0. Setup
# -------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/../../}"

# Load environment
if [ ! -f "$WORK_DIR/scripts/utils/load_env.sh" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m load_env.sh not found in scripts/utils"
    exit 1
fi
# shellcheck source=/dev/null
. "$WORK_DIR/scripts/utils/load_env.sh"

# -------------------------------
# 1. Colors
# -------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -------------------------------
# 2. Ensure Keycloak running
# -------------------------------
get_kc_pid() {
    ps aux | grep -i '[k]eycloak' | awk '{print $2}'
}

keycloak_pid=$(get_kc_pid)
if [ -z "$keycloak_pid" ]; then
    error "Keycloak not running. Start it first."
    exit 1
fi
success "Keycloak running (PID=$keycloak_pid)"

# -------------------------------
# 3. Admin login
# -------------------------------
info "Obtaining admin token..."
"$KC_INSTALL_DIR/bin/kcadm.sh" config credentials \
    --server "$KEYCLOAK_URL" \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"

# -------------------------------
# 4. Create realm if missing
# -------------------------------
if "$KC_INSTALL_DIR/bin/kcadm.sh" get realms/"$KEYCLOAK_REALM" &>/dev/null; then
    warn "Realm $KEYCLOAK_REALM exists, skipping"
else
    info "Creating realm $KEYCLOAK_REALM..."
    "$KC_INSTALL_DIR/bin/kcadm.sh" create realms -s realm="$KEYCLOAK_REALM" -s enabled=true
    success "Realm created."
fi

# -------------------------------
# 5. Key registration (idempotent)
# -------------------------------
register_key() {
    local json_file="$1"
    local alias="$2"
    local name="$3"

    local existing_id
    existing_id=$("$KC_INSTALL_DIR/bin/kcadm.sh" get components -r "$KEYCLOAK_REALM" | jq -r --arg name "$name" '.[] | select(.name==$name) | .id')
    if [ -n "$existing_id" ]; then
        warn "Key $name already exists, skipping registration."
        echo "$existing_id"
        return
    fi

    local payload
    payload=$(jq \
        --arg keystore "$KC_KEYSTORE_PATH" \
        --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
        --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
        --arg keyAlias "$alias" \
        --arg keyPassword "$KC_KEYSTORE_PASSWORD" \
        '.config.keystore=[$keystore] |
         .config.keystorePassword=[$keystorePassword] |
         .config.keystoreType=[$keystoreType] |
         .config.keyAlias=$keyAlias |
         .config.keyPassword=$keyPassword' "$json_file")

    echo "$payload" | "$KC_INSTALL_DIR/bin/kcadm.sh" create components -r "$KEYCLOAK_REALM" -o -f - || warn "Key $name registration failed"
    echo "$("$KC_INSTALL_DIR/bin/kcadm.sh" get components -r "$KEYCLOAK_REALM" | jq -r --arg name "$name" '.[] | select(.name==$name) | .id')"
}

ECDSA_ID=$(register_key "$WORK_DIR/config/keys/issuer_key_ecdsa.json" "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS" "ecdsa-issuer-key")
RSA_SIG_ID=$(register_key "$WORK_DIR/config/keys/issuer_key_rsa.json" "$KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS" "rsa-signing-key")
RSA_ENC_ID=$(register_key "$WORK_DIR/config/keys/encryption_key_rsa.json" "$KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS" "rsa-encryption-key")

# -------------------------------
# 6. Deactivate old keys (idempotent)
# -------------------------------
deactivate_key() {
    local id="$1"
    local name="$2"
    if [ -n "$id" ]; then
        info "Deactivating $name..."
        "$KC_INSTALL_DIR/bin/kcadm.sh" update components/"$id" -r "$KEYCLOAK_REALM" -s 'config.active=["false"]'
        success "$name deactivated."
    else
        warn "Skipping deactivation of $name (ID missing)"
    fi
}

deactivate_key "$ECDSA_ID" "ECDSA Issuer Key"
deactivate_key "$RSA_SIG_ID" "RSA Signing Key"
deactivate_key "$RSA_ENC_ID" "RSA Encryption Key"

# -------------------------------
# 7. Realm attributes
# -------------------------------
info "Updating realm attributes..."
REALM_ATTR=$(cat "$WORK_DIR/config/keycloak/realm-attributes.json")
echo "$REALM_ATTR" | "$KC_INSTALL_DIR/bin/kcadm.sh" update realms/"$KEYCLOAK_REALM" -o -f -
success "Realm attributes updated."

# -------------------------------
# 8. Client scopes (idempotent)
# -------------------------------
info "Creating client scopes..."
CLIENT_SCOPES=$(cat "$WORK_DIR/config/keycloak/client-scope-config.json" | jq --arg ISSUER_DID "$ISSUER_DID" 'map(.attributes["vc.issuer_did"]=$ISSUER_DID)')
echo "$CLIENT_SCOPES" | jq -c '.[]' | while read -r scope; do
    name=$(jq -r '.name' <<< "$scope")
    if "$KC_INSTALL_DIR/bin/kcadm.sh" get client-scopes/$name -r "$KEYCLOAK_REALM" &>/dev/null; then
        warn "Client scope $name exists, skipping."
    else
        echo "$scope" | "$KC_INSTALL_DIR/bin/kcadm.sh" create client-scopes -r "$KEYCLOAK_REALM" -f -
    fi
done
success "Client scopes created."

# -------------------------------
# 9. SAML IdP + mappers (idempotent)
# -------------------------------
info "Creating SAML Identity Providers..."
SAML_IDP=$(cat "$WORK_DIR/config/keycloak/saml-idp-config.json" | jq --arg ENTITY_ID "$ISSUER_DID" '.identityProviders |= map(.config.entityId=$ENTITY_ID)')

echo "$SAML_IDP" | jq -c '.identityProviders[]' | while read -r idp; do
    alias=$(jq -r '.alias' <<< "$idp")
    if "$KC_INSTALL_DIR/bin/kcadm.sh" get identity-provider/instances/$alias -r "$KEYCLOAK_REALM" &>/dev/null; then
        warn "IdP $alias exists, skipping."
    else
        echo "$idp" | "$KC_INSTALL_DIR/bin/kcadm.sh" create identity-provider/instances -r "$KEYCLOAK_REALM" -f -
    fi
done

echo "$SAML_IDP" | jq -c '.identityProviderMappers[]' | while read -r mapper; do
    name=$(jq -r '.name' <<< "$mapper")
    echo "$mapper" | "$KC_INSTALL_DIR/bin/kcadm.sh" create identity-provider/instances/saml/mappers -r "$KEYCLOAK_REALM" -f - || warn "Mapper $name may exist"
done
success "SAML IdPs and mappers configured."

# -------------------------------
# 10. OPENID4VCI clients (idempotent)
# -------------------------------
info "Creating OPENID4VCI clients..."
REST_API_CLIENT=$(cat "$WORK_DIR/config/keycloak/openid4vc-rest-api.json" | jq \
    --arg CLIENT_SECRET "$CLIENT_SECRET" \
    --arg ISSUER_BACKEND_URL "$ISSUER_BACKEND_URL" \
    --arg ISSUER_FRONTEND_URL "$ISSUER_FRONTEND_URL" \
    '.secret=$CLIENT_SECRET |
     .redirectUris+=[($ISSUER_BACKEND_URL+"/*"), "https://localhost:8443/callback"] |
     .webOrigins+=[ $ISSUER_BACKEND_URL, "https://localhost:8443"] |
     .attributes["post.logout.redirect.uris"] += ("##"+$ISSUER_FRONTEND_URL+"/*##"+$ISSUER_FRONTEND_URL)')

echo "$REST_API_CLIENT" | "$KC_INSTALL_DIR/bin/kcadm.sh" create clients -r "$KEYCLOAK_REALM" -o -f - || warn "REST API client may exist"

PUBLIC_CLIENT=$(cat "$WORK_DIR/config/keycloak/oid4vc-demo-public.json" | jq --arg TEST_CLIENT_URL "$TEST_CLIENT_URL" \
    '.rootUrl=$TEST_CLIENT_URL | .baseUrl=$TEST_CLIENT_URL | .redirectUris=[$TEST_CLIENT_URL+"/*"] | .webOrigins=[$TEST_CLIENT_URL] | .attributes["post.logout.redirect.uris"]=($TEST_CLIENT_URL+"##"+$TEST_CLIENT_URL+"/*")')

echo "$PUBLIC_CLIENT" | "$KC_INSTALL_DIR/bin/kcadm.sh" create clients -r "$KEYCLOAK_REALM" -o -f - || warn "Public client may exist"
success "Clients created."

# -------------------------------
# 11. SD-JWT VCT update (optional)
# -------------------------------
info "Updating SD-JWT VCT..."
if cd "$WORK_DIR" && ./scripts/utils/update_sdjwt_vct.sh; then
    success "SD-JWT VCT updated."
else
    warn "SD-JWT VCT update skipped."
fi

# -------------------------------
# 12. Validate OID4VCI credentials
# -------------------------------
info "Validating OID4VCI credentials..."
response=$(curl -k -s -f "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/.well-known/openid-credential-issuer") || {
    error "OID4VCI server not reachable!"
    exit 1
}

for cred in SteuerberaterCredential IdentityCredential KMACredential; do
    if ! jq -e --arg CRED "$cred" '."credential_configurations_supported"[$CRED]' <<< "$response" &>/dev/null; then
        error "Credential $cred missing in OID4VCI config!"
        exit 1
    fi
done
success "OID4VCI credentials validated."

# -------------------------------
# 13. Summary
# -------------------------------
echo -e "\n${GREEN}====== Deployment Summary ======${NC}"
echo "Realm: $KEYCLOAK_REALM"
echo "Keys: ECDSA=$ECDSA_ID, RSA_SIG=$RSA_SIG_ID, RSA_ENC=$RSA_ENC_ID"
echo "Clients: OPENID4VCI REST API, oid4vc-demo-public"
echo "Client scopes and SAML IdPs configured"
echo -e "${GREEN}===============================${NC}\n"
success "Deployment completed."
