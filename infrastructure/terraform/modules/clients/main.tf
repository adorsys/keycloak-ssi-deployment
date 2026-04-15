terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  scope_assignment_clients = length(var.optional_client_scope_client_ids) == 0 ? keycloak_openid_client.clients : {
    for client_id, client in keycloak_openid_client.clients : client_id => client
    if contains(var.optional_client_scope_client_ids, client_id)
  }
}


resource "keycloak_openid_client" "clients" {
  for_each = var.clients

  realm_id                     = var.realm_id
  client_id                    = each.key
  name                         = each.value.name
  enabled                      = each.value.enabled
  access_type                  = each.value.access_type
  standard_flow_enabled        = each.value.standard_flow_enabled
  direct_access_grants_enabled = each.value.direct_access_grants_enabled
  valid_redirect_uris          = each.value.valid_redirect_uris
  web_origins                  = each.value.web_origins
  client_secret                = try(each.value.client_secret, null)
  full_scope_allowed           = each.value.full_scope_allowed
}

resource "null_resource" "apply_client_attributes" {
  for_each = keycloak_openid_client.clients

  triggers = {
    client_id       = each.value.id
    attributes_hash = jsonencode(var.clients[each.key].attributes)
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"

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

      CLIENT_CFG=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/clients/${each.value.id}" -H "Authorization: Bearer $TOKEN")

      if ! echo "$CLIENT_CFG" | jq -e . > /dev/null 2>&1; then
        echo "Failed to retrieve client configuration or invalid JSON for client ${each.key}" >&2
        exit 1
      fi

      ATTRIBUTES='${jsonencode(var.clients[each.key].attributes)}'

      UPDATED=$(echo "$CLIENT_CFG" | jq --argjson attrs "$ATTRIBUTES" '.attributes += $attrs')

      curl -s -k -X PUT "$KC_URL/admin/realms/$REALM/clients/${each.value.id}" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$UPDATED" > /dev/null

      echo "Attributes for client ${each.key} applied."
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "apply_optional_scopes" {
  for_each = local.scope_assignment_clients

  depends_on = [null_resource.apply_client_attributes]

  triggers = {
    client_id       = each.value.id
    scopes_applied  = jsonencode(var.client_scopes_dependency)
    optional_scopes = jsonencode(var.optional_client_scopes)
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"
      CLIENT_ID="${each.value.id}"
      OPTIONAL_SCOPES='${jsonencode(var.optional_client_scopes)}'

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

      # Get all available scopes in the realm
      ALL_SCOPES=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/client-scopes" -H "Authorization: Bearer $TOKEN")

      # For each optional scope, find its ID and add it to the client
      for scope_name in $(echo "$OPTIONAL_SCOPES" | jq -r '.[]'); do
        SCOPE_ID=$(echo "$ALL_SCOPES" | jq -r --arg name "$scope_name" '.[] | select(.name == $name) | .id')
        if [ -n "$SCOPE_ID" ]; then
          HTTP_CODE=$(curl -s -k -w "%%{http_code}" -o /dev/null -X PUT "$KC_URL/admin/realms/$REALM/clients/$CLIENT_ID/optional-client-scopes/$SCOPE_ID" \
            -H "Authorization: Bearer $TOKEN")
          if [ "$HTTP_CODE" -ge 400 ]; then
            echo "Failed to assign optional scope $scope_name to client ${each.key}. HTTP $HTTP_CODE" >&2
            exit 1
          fi
          echo "Assigned optional scope $scope_name to client ${each.key}."
        else
          echo "Warning: Optional scope $scope_name not found."
        fi
      done
    EOT
    interpreter = ["bash", "-c"]
  }
}
