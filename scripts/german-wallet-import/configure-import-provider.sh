#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: KEYCLOAK_ADMIN_PASSWORD=<password> $0 <keycloak-url> <realm> <idp-alias>" >&2
  exit 1
fi

keycloak_url="$1"
realm="$2"
idp_alias="$3"
admin_password="${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD is required}"

token="$(curl -ksSf -X POST "$keycloak_url/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username=admin \
  --data-urlencode "password=$admin_password" \
  --data-urlencode grant_type=password | jq -er .access_token)"

api="$keycloak_url/admin/realms/$realm/identity-provider/instances"
idp_payload="$(jq -cn --arg alias "$idp_alias" '{
  alias:$alias,
  displayName:"OpenID4VP verified credential import",
  providerId:"oid4vp-plugin-import",
  enabled:true,
  hideOnLogin:true,
  trustEmail:false,
  storeToken:false,
  addReadTokenRoleOnCreate:false,
  authenticateByDefault:false,
  linkOnly:true,
  config:{syncMode:"FORCE"}
}')"

status="$(curl -ksS -o /dev/null -w '%{http_code}' "$api/$idp_alias" \
  -H "Authorization: Bearer $token")"
case "$status" in
  200)
    existing_provider="$(curl -ksSf "$api/$idp_alias" \
      -H "Authorization: Bearer $token" | jq -r .providerId)"
    if [[ "$existing_provider" != "oid4vp-plugin-import" ]]; then
      echo "Identity provider '$idp_alias' already uses provider '$existing_provider'; refusing to replace it." >&2
      exit 1
    fi
    curl -ksSf -X PUT "$api/$idp_alias" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      --data "$idp_payload" >/dev/null
    ;;
  404)
    curl -ksSf -X POST "$api" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      --data "$idp_payload" >/dev/null
    ;;
  *)
    echo "Cannot inspect import identity provider '$idp_alias' (HTTP $status)." >&2
    exit 1
    ;;
esac

upsert_mapper() {
  local name="$1"
  local claim="$2"
  local attribute="$3"
  local mapper_id payload

  payload="$(jq -cn \
    --arg name "$name" --arg alias "$idp_alias" --arg claim "$claim" --arg attribute "$attribute" \
    '{name:$name,identityProviderAlias:$alias,identityProviderMapper:"oid4vp-user-attribute-idp-mapper",config:{claim:$claim,"user.attribute":$attribute,syncMode:"INHERIT"}}')"
  mapper_id="$(curl -ksSf "$api/$idp_alias/mappers" -H "Authorization: Bearer $token" \
    | jq -r --arg name "$name" '.[] | select(.name == $name) | .id' | head -n 1)"

  if [[ -n "$mapper_id" ]]; then
    curl -ksSf -X PUT "$api/$idp_alias/mappers/$mapper_id" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      --data "$(jq -c --arg id "$mapper_id" '. + {id:$id}' <<<"$payload")" >/dev/null
  else
    curl -ksSf -X POST "$api/$idp_alias/mappers" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      --data "$payload" >/dev/null
  fi
}

# Mapper claim syntax is a dotted JSON path; dots in the mDoc namespace are escaped.
namespace='eu\.europa\.ec\.eudi\.pid\.1'
upsert_mapper german-pid-username "$namespace.given_name" username
upsert_mapper german-pid-given-name "$namespace.given_name" firstName
upsert_mapper german-pid-family-name "$namespace.family_name" lastName
upsert_mapper german-pid-birth-date "$namespace.birth_date" oid4vpBirthDate
upsert_mapper german-pid-issuing-country "$namespace.issuing_country" oid4vpIssuingCountry

echo "Configured hidden import provider '$idp_alias' and German PID claim mappers."
