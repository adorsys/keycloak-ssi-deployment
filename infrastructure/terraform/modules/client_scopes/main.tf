terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  # Find all .json files in the scopes directory
  client_scope_files = fileset("${path.root}/jsons/scopes", "*.json")
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  for_each = toset(local.client_scope_files)

  depends_on = [var.realm_id]

  triggers = {
    # Trigger a re-run if the file content changes
    client_scope_hash = filemd5("${path.root}/jsons/scopes/${each.value}")
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"

      TOKEN=$(curl -k -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      echo "Importing OID4VC client scope from ${each.value} via curl..."

      # Import the client scope
      HTTP_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"${path.root}/jsons/scopes/${each.value}")

      if [ "$HTTP_CODE" -ge 400 ]; then
        echo "Failed to import client scope from ${each.value}. HTTP $HTTP_CODE" >&2
        exit 1
      fi

      echo "Custom OID4VC client scope from ${each.value} imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}

