#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# WORK_DIR is set by the CLI
source "$WORK_DIR/src/utils/helper.sh"
init_script

FLOW_ALIAS="oid4vp auth"
AUTH_PROVIDER_ID="sd-jwt-authenticator"
CONFIG_ALIAS="sdjwt-auth-config"
VCT="stbk_westfalen_lippe,https://credentials.example.com/identity_credential,person_vct"



# Get admin token
TOKEN=$(curl -s -k -X POST "$URLS_ADMIN_ADDR/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli" \
    -d "username=$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" \
    -d "password=$(urlencode "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD")" \
    -d "grant_type=password" | jq -r .access_token)

[[ -z "$TOKEN" || "$TOKEN" == "null" ]] && error "Failed to obtain Keycloak admin token"

# Find flow
FLOW=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
    "$URLS_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/flows" \
    | jq -c ".[] | select(.alias==\"$FLOW_ALIAS\")")

[[ -z "$FLOW" ]] && log "Flow $FLOW_ALIAS not found. Skipping." && exit 0

FLOW_ALIAS_ENC=$(urlencode "$FLOW_ALIAS")
EXECUTIONS=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
    "$URLS_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/flows/$FLOW_ALIAS_ENC/executions")

EXEC=$(echo "$EXECUTIONS" | jq -c ".[] | select(.providerId==\"$AUTH_PROVIDER_ID\" or .authenticator==\"$AUTH_PROVIDER_ID\")" | head -n1)

[[ -z "$EXEC" ]] && log "Execution for $AUTH_PROVIDER_ID not found. Skipping." && exit 0

EXEC_ID=$(echo "$EXEC" | jq -r .id)
CFG_ID=$(echo "$EXEC" | jq -r .authenticationConfig)

if [[ "$CFG_ID" != "null" && -n "$CFG_ID" ]]; then
    log "Updating existing SD-JWT config..."
    CFG=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
        "$URLS_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/config/$CFG_ID")
    NEW_CFG=$(echo "$CFG" | jq --arg VCT "$VCT" '.config.vct = $VCT')
    curl -s -k -X PUT "$URLS_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/config/$CFG_ID" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "$NEW_CFG" > /dev/null
    log "Updated SD-JWT authenticator vct: $VCT"
else
    log "Creating new SD-JWT config..."
    BODY=$(jq -n --arg alias "$CONFIG_ALIAS" --arg VCT "$VCT" \
        '{ alias: $alias, config: { vct: $VCT, enforceNbfClaim: "false", enforceExpClaim: "false", kbJwtMaxAge: "60" } }')
    curl -s -k -X POST "$URLS_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/executions/$EXEC_ID/config" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$BODY" > /dev/null
    log "Created SD-JWT authenticator config vct: $VCT"
fi
