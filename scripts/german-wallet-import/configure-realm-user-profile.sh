#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: KEYCLOAK_ADMIN_PASSWORD=<password> $0 <keycloak-url> <realm>" >&2
  exit 1
fi

keycloak_url="$1"
realm="$2"
admin_password="${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD is required}"

token="$(curl -ksSf -X POST "$keycloak_url/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username=admin \
  --data-urlencode "password=$admin_password" \
  --data-urlencode grant_type=password | jq -er .access_token)"

profile_api="$keycloak_url/admin/realms/$realm/users/profile"
realm_api="$keycloak_url/admin/realms/$realm"

registration_email_as_username="$(curl -ksSf "$realm_api" \
  -H "Authorization: Bearer $token" | jq -r '.registrationEmailAsUsername // false')"
if [[ "$registration_email_as_username" != "false" ]]; then
  echo "Realm '$realm' uses email as username; a German PID without email cannot be imported." >&2
  echo "Set registration_email_as_username=false before configuring its user profile." >&2
  exit 1
fi

current_profile="$(curl -ksSf "$profile_api" -H "Authorization: Bearer $token")"

jq -e '.attributes | type == "array"' <<<"$current_profile" >/dev/null || {
  echo "Realm '$realm' returned an invalid user-profile representation." >&2
  exit 1
}

updated_profile="$(jq -c '
  .attributes |= map(if .name == "email" then del(.required) else . end)
  | .unmanagedAttributePolicy = "ADMIN_VIEW"
' <<<"$current_profile")"

curl -ksSf -X PUT "$profile_api" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  --data "$updated_profile" >/dev/null

curl -ksSf "$profile_api" -H "Authorization: Bearer $token" \
  | jq -e '
      .unmanagedAttributePolicy == "ADMIN_VIEW"
      and ([.attributes[] | select(.name == "email" and has("required"))] | length == 0)
    ' >/dev/null

echo "Configured realm '$realm' for email-optional German PID imports and admin-visible mapped attributes."
