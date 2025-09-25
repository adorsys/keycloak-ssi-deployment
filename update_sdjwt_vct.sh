#!/bin/bash

# Source common env variables
. load_env.sh

FLOW_ALIAS="oid4vp auth"
AUTH_PROVIDER_ID="sd-jwt-authenticator"
CONFIG_ALIAS="sdjwt-auth-config"
VCT="stbk_westfalen_lippe,https://credentials.example.com/identity_credential,person_vct"

# Function to URL-encode strings
urlencode() {
  local raw="$1"
  jq -rn --arg str "$raw" '$str|@uri'
}

get_token() {
  local password_encoded
  password_encoded=$(urlencode "$KC_BOOTSTRAP_ADMIN_PASSWORD")

  local token
  token=$(curl -s -k -X POST "$KEYCLOAK_ADMIN_ADDR/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli" \
    -d "username=$KC_BOOTSTRAP_ADMIN_USERNAME" \
    -d "password=$password_encoded" \
    -d "grant_type=password" | jq -r .access_token)

  if [ -z "$token" ] || [ "$token" == "null" ]; then
    echo "Failed to get access token from Keycloak" >&2
    exit 1
  fi

  echo "$token"
}

TOKEN=$(get_token)

flow=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/flows" | \
  jq -c ".[] | select(.alias==\"$FLOW_ALIAS\")")

if [ -z "$flow" ]; then
  echo "Flow '$FLOW_ALIAS' not found in realm '$KEYCLOAK_REALM'. Skipping." >&2
  exit 0
fi

# URL-encode flow alias
FLOW_ALIAS_ENC=$(urlencode "$FLOW_ALIAS")

executions=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/flows/$FLOW_ALIAS_ENC/executions")

exec=$(echo "$executions" | jq -c ".[] | select(.providerId==\"$AUTH_PROVIDER_ID\" or .authenticator==\"$AUTH_PROVIDER_ID\")" | head -n1)

if [ -z "$exec" ]; then
  echo "Execution for provider '$AUTH_PROVIDER_ID' not found under flow '$FLOW_ALIAS'. Skipping." >&2
  exit 0
fi

exec_id=$(echo "$exec" | jq -r .id)
cfg_id=$(echo "$exec" | jq -r .authenticationConfig)

if [ "$cfg_id" != "null" ] && [ -n "$cfg_id" ]; then
  # Update existing config
  cfg=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/config/$cfg_id")
  new_cfg=$(echo "$cfg" | jq --arg VCT "$VCT" '.config.vct = $VCT')
  curl -s -k -X PUT "$KEYCLOAK_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/config/$cfg_id" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$new_cfg" > /dev/null
  echo "Updated sd-jwt authenticator config vct to: $VCT"
else
  # Create new config on execution
  body=$(jq -n \
    --arg alias "$CONFIG_ALIAS" \
    --arg VCT "$VCT" \
    '{ alias: $alias, config: { vct: $VCT, enforceNbfClaim: "false", enforceExpClaim: "false", kbJwtMaxAge: "60" } }')
  curl -s -k -X POST "$KEYCLOAK_ADMIN_ADDR/admin/realms/$KEYCLOAK_REALM/authentication/executions/$exec_id/config" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$body" > /dev/null
  echo "Created sd-jwt authenticator config with vct: $VCT"
fi
