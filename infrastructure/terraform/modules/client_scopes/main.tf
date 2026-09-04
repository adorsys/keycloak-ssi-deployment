terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  # When explicit scope files are provided, apply only those; otherwise apply all JSON scopes.
  client_scope_files = length(var.scope_files) > 0 ? toset(var.scope_files) : toset(fileset("${path.root}/jsons/scopes", "*.json"))
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  for_each = toset(local.client_scope_files)

  depends_on = [var.realm_id]

  triggers = {
    # Trigger a re-run if the file content changes
    client_scope_hash = filemd5("${path.root}/jsons/scopes/${each.value}")
    # If the realm was recreated/reset, ensure we re-import missing scopes.
    realm_id   = var.realm_id
    realm_name = var.realm_name
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

      SCOPE_FILE="${path.root}/jsons/scopes/${each.value}"
      SCOPE_NAME=$(jq -r '.name' "$SCOPE_FILE")

      if [ -z "$SCOPE_NAME" ] || [ "$SCOPE_NAME" = "null" ]; then
        echo "Missing 'name' in $SCOPE_FILE" >&2
        exit 1
      fi

      echo "Applying OID4VC client scope '$SCOPE_NAME' from ${each.value} via curl..."

      # Import the client scope
      HTTP_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$SCOPE_FILE")

      if [ "$HTTP_CODE" -eq 409 ]; then
        echo "Client scope '$SCOPE_NAME' already exists (HTTP 409). Updating it..."

        EXISTING_SCOPE_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/client-scopes?search=$SCOPE_NAME" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" | jq -r --arg name "$SCOPE_NAME" '.[] | select(.name == $name) | .id' | head -n 1)

        if [ -z "$EXISTING_SCOPE_ID" ] || [ "$EXISTING_SCOPE_ID" = "null" ]; then
          echo "Could not resolve existing scope id for '$SCOPE_NAME'" >&2
          exit 1
        fi

        UPDATE_PAYLOAD=$(jq --arg id "$EXISTING_SCOPE_ID" '.id = $id' "$SCOPE_FILE")

        UPDATE_HTTP_CODE=$(echo "$UPDATE_PAYLOAD" | curl -k -s -o /dev/null -w "%%{http_code}" -X PUT "$KC_URL/admin/realms/${var.realm_name}/client-scopes/$EXISTING_SCOPE_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-)

        if [ "$UPDATE_HTTP_CODE" -ge 400 ]; then
          echo "Failed to update existing client scope '$SCOPE_NAME'. HTTP $UPDATE_HTTP_CODE" >&2
          exit 1
        fi
        echo "Updated existing client scope '$SCOPE_NAME' successfully."
      elif [ "$HTTP_CODE" -ge 400 ]; then
        echo "Failed to import client scope from ${each.value}. HTTP $HTTP_CODE" >&2
        exit 1
      else
        echo "Custom OID4VC client scope from ${each.value} imported successfully."
      fi

    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "prune_unconfigured_client_scopes" {
  count = length(var.prune_unconfigured_scopes) > 0 ? 1 : 0

  triggers = {
    prune_scopes = join(",", sort(var.prune_unconfigured_scopes))
    realm_id     = var.realm_id
    realm_name   = var.realm_name
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"

      TOKEN=$(curl -k -s -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token for scope pruning" >&2
        exit 1
      fi

      ALL_SCOPES=$(curl -k -s -X GET "$KC_URL/admin/realms/$REALM/client-scopes" -H "Authorization: Bearer $TOKEN")

      PRUNE_LIST='${jsonencode(var.prune_unconfigured_scopes)}'
      for scope_name in $(echo "$PRUNE_LIST" | jq -r '.[]'); do
        SCOPE_ID=$(echo "$ALL_SCOPES" | jq -r --arg name "$scope_name" '.[] | select(.name == $name) | .id')
        if [ -n "$SCOPE_ID" ] && [ "$SCOPE_ID" != "null" ]; then
          echo "Pruning unconfigured client scope '$scope_name' ($SCOPE_ID) from realm $REALM..."
          curl -k -s -o /dev/null -X DELETE "$KC_URL/admin/realms/$REALM/client-scopes/$SCOPE_ID" -H "Authorization: Bearer $TOKEN"
        fi
      done
    EOT
    interpreter = ["bash", "-c"]
  }
}
