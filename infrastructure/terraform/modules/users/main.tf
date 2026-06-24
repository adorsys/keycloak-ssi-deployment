terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

resource "keycloak_user" "francis" {
  realm_id   = var.realm_id
  username   = var.username
  first_name = var.first_name
  last_name  = var.last_name
  email      = var.email
  enabled    = true
  initial_password {
    value     = var.initial_password
    temporary = false
  }
}

# Lookup the OpenID4VCI credential-offer-create realm role (required for credential offer creation)
data "keycloak_role" "credential_offer_create" {
  realm_id = var.realm_id
  name     = "credential-offer-create"
}

# Assign the credential-offer-create realm role to the user
resource "keycloak_user_roles" "francis_realm_roles" {
  realm_id = var.realm_id
  user_id  = keycloak_user.francis.id
  # Keep default/composite realm roles intact; only ensure this role is present.
  exhaustive = false

  role_ids = [
    data.keycloak_role.credential_offer_create.id,
  ]
}

resource "null_resource" "grant_verifiable_credentials" {
  count = length(var.verifiable_credentials) > 0 ? 1 : 0

  depends_on = [keycloak_user.francis, keycloak_user_roles.francis_realm_roles]

  triggers = {
    user_id                  = keycloak_user.francis.id
    credentials_hash         = jsonencode(var.verifiable_credentials)
    client_scopes_dependency = jsonencode(var.client_scopes_dependency)
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"
      USER_ID="${keycloak_user.francis.id}"
      CREDENTIALS='${jsonencode(var.verifiable_credentials)}'

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      EXISTING=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/users/$USER_ID/vc/credentials" \
        -H "Authorization: Bearer $TOKEN")

      if ! echo "$EXISTING" | jq -e . > /dev/null 2>&1; then
        echo "Failed to retrieve verifiable credentials for user ${var.username}" >&2
        exit 1
      fi

      for credential_scope in $(echo "$CREDENTIALS" | jq -r '.[]'); do
        if echo "$EXISTING" | jq -e --arg scope "$credential_scope" '.[] | select(.credentialScopeName == $scope)' > /dev/null; then
          echo "Verifiable credential $credential_scope already granted to ${var.username}."
          continue
        fi

        HTTP_CODE=$(jq -n --arg credentialScopeName "$credential_scope" '{credentialScopeName: $credentialScopeName}' \
          | curl -s -k -w "%%{http_code}" -o /tmp/keycloak-vc-grant-response.json \
            -X POST "$KC_URL/admin/realms/$REALM/users/$USER_ID/vc/credentials" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d @-)

        if [ "$HTTP_CODE" -ge 400 ]; then
          echo "Failed to grant verifiable credential $credential_scope to ${var.username}. HTTP $HTTP_CODE" >&2
          cat /tmp/keycloak-vc-grant-response.json >&2
          exit 1
        fi

        echo "Granted verifiable credential $credential_scope to ${var.username}."
      done
    EOT
    interpreter = ["bash", "-c"]
  }
}
