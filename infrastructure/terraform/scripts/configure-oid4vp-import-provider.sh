#!/usr/bin/env bash
set -euo pipefail

: "${KEYCLOAK_BASE_URL:?KEYCLOAK_BASE_URL is required}"
: "${KEYCLOAK_REALM:?KEYCLOAK_REALM is required}"
: "${KEYCLOAK_ADMIN_NAME:?KEYCLOAK_ADMIN_NAME is required}"
: "${KEYCLOAK_ADMIN_SECRET:?KEYCLOAK_ADMIN_SECRET is required}"
: "${OID4VP_IMPORT_ALIAS:?OID4VP_IMPORT_ALIAS is required}"
: "${OID4VP_IMPORT_MAPPERS:?OID4VP_IMPORT_MAPPERS is required}"
: "${OID4VP_IMPORT_EMAIL_REQUIRED:?OID4VP_IMPORT_EMAIL_REQUIRED is required}"

case "$OID4VP_IMPORT_EMAIL_REQUIRED" in
  true|false) ;;
  *) echo "OID4VP_IMPORT_EMAIL_REQUIRED must be true or false." >&2; exit 1 ;;
esac

if [[ ! "$OID4VP_IMPORT_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Import provider alias contains unsupported characters." >&2
  exit 1
fi

base_url="${KEYCLOAK_BASE_URL%/}"
realm_url="$base_url/admin/realms/$KEYCLOAK_REALM"
token_url="$base_url/realms/master/protocol/openid-connect/token"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

token="$(curl --silent --show-error --insecure --fail \
  --request POST "$token_url" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id=admin-cli' \
  --data-urlencode "username=$KEYCLOAK_ADMIN_NAME" \
  --data-urlencode "password=$KEYCLOAK_ADMIN_SECRET" \
  --data-urlencode 'grant_type=password' | jq -er '.access_token')"

auth_header="Authorization: Bearer $token"
provider_url="$realm_url/identity-provider/instances/$OID4VP_IMPORT_ALIAS"
provider_body="$(jq -cn --arg alias "$OID4VP_IMPORT_ALIAS" '{
  alias: $alias,
  providerId: "oid4vp-plugin-import",
  enabled: true,
  linkOnly: true,
  storeToken: false,
  trustEmail: false,
  config: {}
}')"

provider_status="$(curl --silent --show-error --insecure \
  --output "$response_file" --write-out '%{http_code}' \
  --header "$auth_header" "$provider_url")"

case "$provider_status" in
  200)
    current_provider="$(jq -r '.providerId // empty' "$response_file")"
    if [[ "$current_provider" != "oid4vp-plugin-import" ]]; then
      echo "Identity provider alias '$OID4VP_IMPORT_ALIAS' is already used by provider '$current_provider'." >&2
      exit 1
    fi
    curl --silent --show-error --insecure --fail \
      --request PUT "$provider_url" \
      --header "$auth_header" \
      --header 'Content-Type: application/json' \
      --data "$provider_body" >/dev/null
    ;;
  404)
    curl --silent --show-error --insecure --fail \
      --request POST "$realm_url/identity-provider/instances" \
      --header "$auth_header" \
      --header 'Content-Type: application/json' \
      --data "$provider_body" >/dev/null
    ;;
  *)
    echo "Could not inspect import identity provider (HTTP $provider_status): $(cat "$response_file")" >&2
    exit 1
    ;;
esac

mapper_list_url="$realm_url/identity-provider/instances/$OID4VP_IMPORT_ALIAS/mappers"
curl --silent --show-error --insecure --fail \
  --header "$auth_header" "$mapper_list_url" >"$response_file"

while IFS= read -r mapper; do
  mapper_name="$(jq -r '.name' <<<"$mapper")"
  mapper_id="$(jq -r --arg name "$mapper_name" \
    '.[] | select(.name == $name) | .id' "$response_file" | head -n 1)"
  mapper_type="$(jq -r --arg name "$mapper_name" \
    '.[] | select(.name == $name) | .identityProviderMapper' "$response_file" | head -n 1)"

  if [[ -n "$mapper_id" && "$mapper_type" != "oid4vp-user-attribute-idp-mapper" ]]; then
    echo "Mapper '$mapper_name' already exists with an unexpected type '$mapper_type'." >&2
    exit 1
  fi

  mapper_body="$(jq -cn --arg name "$mapper_name" \
    --arg alias "$OID4VP_IMPORT_ALIAS" \
    --arg claim "$(jq -r '.claim' <<<"$mapper")" \
    --arg attribute "$(jq -r '.attribute' <<<"$mapper")" \
    --arg id "$mapper_id" \
    '({name: $name, identityProviderAlias: $alias,
       identityProviderMapper: "oid4vp-user-attribute-idp-mapper",
       config: {claim: $claim, "user.attribute": $attribute, syncMode: "INHERIT"}})
     + (if $id == "" then {} else {id: $id} end)')"

  if [[ -n "$mapper_id" ]]; then
    curl --silent --show-error --insecure --fail \
      --request PUT "$mapper_list_url/$mapper_id" \
      --header "$auth_header" \
      --header 'Content-Type: application/json' \
      --data "$mapper_body" >/dev/null
  else
    curl --silent --show-error --insecure --fail \
      --request POST "$mapper_list_url" \
      --header "$auth_header" \
      --header 'Content-Type: application/json' \
      --data "$mapper_body" >/dev/null
  fi
done < <(jq -c '.[]' <<<"$OID4VP_IMPORT_MAPPERS")

user_profile_url="$realm_url/users/profile"
curl --silent --show-error --insecure --fail \
  --header "$auth_header" "$user_profile_url" >"$response_file"

if ! jq -e '(.attributes | type == "array") and any(.attributes[]; .name == "email")' \
  "$response_file" >/dev/null; then
  echo "Realm user-profile configuration has no email attribute; cannot configure its requiredness." >&2
  exit 1
fi

user_profile_body="$(jq --argjson email_required "$OID4VP_IMPORT_EMAIL_REQUIRED" '
  .attributes |= map(
    if .name == "email" then
      if $email_required then
        .required = ((.required // {}) as $required |
          $required + {
            roles: (((($required.roles // []) - ["user"]) + ["user"]) | unique)
          })
      else
        del(.required)
      end
    else . end
  )
' "$response_file")"

profile_status="$(curl --silent --show-error --insecure \
  --output "$response_file" --write-out '%{http_code}' \
  --request PUT "$user_profile_url" \
  --header "$auth_header" \
  --header 'Content-Type: application/json' \
  --data "$user_profile_body")"

if [[ ! "$profile_status" =~ ^2[0-9][0-9]$ ]]; then
  echo "Could not configure the realm email-required setting (HTTP $profile_status)." >&2
  exit 1
fi

echo "Configured hidden OID4VP import provider '$OID4VP_IMPORT_ALIAS' and its user-attribute mappers in realm '$KEYCLOAK_REALM'."
if [[ "$OID4VP_IMPORT_EMAIL_REQUIRED" == "true" ]]; then
  echo "Realm user-profile email remains required for user accounts."
else
  echo "Realm user-profile email is optional for user accounts. This setting affects all users in this realm."
fi
