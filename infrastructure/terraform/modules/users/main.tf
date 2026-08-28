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

resource "keycloak_user" "max_mustermann" {
  realm_id   = var.realm_id
  username   = var.max_mustermann_username
  first_name = var.max_mustermann_first_name
  last_name  = var.max_mustermann_last_name
  email      = var.max_mustermann_email
  enabled    = true

  initial_password {
    value     = var.max_mustermann_initial_password
    temporary = false
  }
}

locals {
  managed_users = {
    francis = {
      id       = keycloak_user.francis.id
      username = keycloak_user.francis.username
    }
    max_mustermann = {
      id       = keycloak_user.max_mustermann.id
      username = keycloak_user.max_mustermann.username
    }
  }
}

# Keycloak 26.7 requires a user-verifiable-credential grant in addition to
# creating the credential client scope and assigning that scope to a client.
resource "null_resource" "grant_verifiable_credentials" {
  for_each = length(var.verifiable_credentials) > 0 ? local.managed_users : {}

  triggers = {
    user_id                  = each.value.id
    credentials_hash         = sha256(jsonencode(var.verifiable_credentials))
    client_scopes_dependency = sha256(jsonencode(var.client_scopes_dependency))
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"
      USER_ID="${each.value.id}"
      USERNAME="${each.value.username}"
      CREDENTIALS='${jsonencode(var.verifiable_credentials)}'
      RESPONSE_FILE=$(mktemp)
      trap 'rm -f "$RESPONSE_FILE"' EXIT

      TOKEN_RESPONSE=$(curl -sS -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=admin-cli" \
        --data-urlencode "username=admin" \
        --data-urlencode "password=${var.admin_password}" \
        --data-urlencode "grant_type=password")
      TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

      if [ -z "$TOKEN" ]; then
        echo "Failed to obtain an admin token while granting credentials to $USERNAME." >&2
        exit 1
      fi

      EXISTING=$(curl -sS -k \
        "$KC_URL/admin/realms/$REALM/users/$USER_ID/vc/credentials" \
        -H "Authorization: Bearer $TOKEN")

      if ! echo "$EXISTING" | jq -e 'type == "array"' > /dev/null; then
        echo "Failed to retrieve verifiable credentials for $USERNAME." >&2
        echo "$EXISTING" >&2
        exit 1
      fi

      echo "$CREDENTIALS" | jq -r '.[]' | while IFS= read -r credential_scope; do
        if echo "$EXISTING" | jq -e --arg scope "$credential_scope" \
          'any(.credentialScopeName == $scope)' > /dev/null; then
          echo "Verifiable credential $credential_scope is already granted to $USERNAME."
          continue
        fi

        HTTP_CODE=$(jq -n --arg credentialScopeName "$credential_scope" \
          '{credentialScopeName: $credentialScopeName}' \
          | curl -sS -k -o "$RESPONSE_FILE" -w "%%{http_code}" \
            -X POST "$KC_URL/admin/realms/$REALM/users/$USER_ID/vc/credentials" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            --data-binary @-)

        if [ "$HTTP_CODE" -eq 409 ]; then
          echo "Verifiable credential $credential_scope is already granted to $USERNAME."
        elif [ "$HTTP_CODE" -ge 400 ]; then
          echo "Failed to grant verifiable credential $credential_scope to $USERNAME. HTTP $HTTP_CODE" >&2
          cat "$RESPONSE_FILE" >&2
          exit 1
        else
          echo "Granted verifiable credential $credential_scope to $USERNAME."
        fi
      done
    EOT
    interpreter = ["bash", "-c"]
  }
}
