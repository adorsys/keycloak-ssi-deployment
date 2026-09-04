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
  count    = var.assign_credential_offer_role ? 1 : 0
  realm_id = var.realm_id
  name     = "credential-offer-create"
}

# Assign the credential-offer-create realm role to the user
resource "keycloak_user_roles" "francis_realm_roles" {
  count    = var.assign_credential_offer_role ? 1 : 0
  realm_id = var.realm_id
  user_id  = keycloak_user.francis.id
  # Keep default/composite realm roles intact; only ensure this role is present.
  exhaustive = false

  role_ids = [
    data.keycloak_role.credential_offer_create[0].id,
  ]
}

# Keycloak main stores an explicit per-user grant for every credential the user
# is allowed to issue. Creating the client scope only publishes metadata; it
# does not create this user-to-credential association.
resource "null_resource" "grant_verifiable_credentials" {
  for_each = toset(var.verifiable_credential_scope_names)

  triggers = {
    user_id                  = keycloak_user.francis.id
    credential_scope_name    = each.value
    client_scopes_dependency = sha256(jsonencode(var.client_scopes_dependency))
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      TOKEN=$(curl -s -k -X POST "${var.keycloak_url}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=${var.admin_password}" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      CREDENTIALS_URL="${var.keycloak_url}/admin/realms/${var.realm_name}/users/${keycloak_user.francis.id}/vc/credentials"
      EXISTING=$(curl -s -k "$CREDENTIALS_URL" -H "Authorization: Bearer $TOKEN")

      if echo "$EXISTING" | jq -e --arg scope "${each.value}" \
          'any(.[]; .credentialScopeName == $scope)' >/dev/null; then
        echo "Verifiable credential ${each.value} is already granted to ${keycloak_user.francis.username}."
        exit 0
      fi

      curl -s -k --fail-with-body -X POST "$CREDENTIALS_URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '${jsonencode({ credentialScopeName = each.value })}' >/dev/null

      echo "Granted verifiable credential ${each.value} to ${keycloak_user.francis.username}."
    EOT
    interpreter = ["bash", "-c"]
  }
}
