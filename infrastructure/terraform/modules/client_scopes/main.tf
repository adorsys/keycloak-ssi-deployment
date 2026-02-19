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

# Wait for realm to be ready before creating client scopes
resource "null_resource" "wait_for_realm" {
  triggers = {
    realm_id = var.realm_id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"
      export TARGET_REALM="${var.realm_name}"

      # Wait for Keycloak to be accessible
      MAX_RETRIES=30
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -k -s -f "$KC_URL/realms/$KC_REALM" > /dev/null 2>&1; then
          echo "Keycloak is accessible"
          break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for Keycloak to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
      done

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Keycloak is not accessible after $MAX_RETRIES retries" >&2
        exit 1
      fi

      # Get admin token
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

      # Wait for realm to exist
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X GET "$KC_URL/admin/realms/$TARGET_REALM" \
          -H "Authorization: Bearer $TOKEN")
        
        if [ "$HTTP_CODE" -eq 200 ]; then
          echo "Realm $TARGET_REALM exists and is ready"
          break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for realm $TARGET_REALM to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
      done

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Realm $TARGET_REALM is not ready after $MAX_RETRIES retries" >&2
        exit 1
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  for_each = toset(local.client_scope_files)

  depends_on = [null_resource.wait_for_realm]

  triggers = {
    client_scope_hash = filemd5("${path.root}/jsons/scopes/${each.value}")
    kc_url            = var.keycloak_url
    realm_id          = var.realm_id
    realm_name        = var.realm_name
    status_list_enabled = var.status_list_enabled
    script_hash       = filemd5("${path.module}/main.tf")
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"
      export TARGET_REALM="${var.realm_name}"

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

      echo "Importing OID4VC client scope from ${each.value}..."

      ISSUER_DID="$KC_URL/realms/$TARGET_REALM"
      STATUS_LIST_ENABLED="${var.status_list_enabled}"
      if [ "$STATUS_LIST_ENABLED" = "true" ]; then
        PROCESSED_JSON=$(jq --arg issuer_did "$ISSUER_DID" '.attributes["vc.issuer_did"] = $issuer_did' "${path.root}/jsons/scopes/${each.value}")
      else
        PROCESSED_JSON=$(jq --arg issuer_did "$ISSUER_DID" '
          .attributes["vc.issuer_did"] = $issuer_did |
          .protocolMappers = (.protocolMappers // [] | map(select(.protocolMapper != "oid4vc-status-list-claim-mapper")))
        ' "${path.root}/jsons/scopes/${each.value}")
      fi

      HTTP_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PROCESSED_JSON")

      SCOPE_NAME=$(echo "$PROCESSED_JSON" | jq -r .name)
      
      if [ "$HTTP_CODE" -eq 409 ]; then
        echo "Client scope from ${each.value} already exists (HTTP 409). Updating attributes..."
        
        SCOPE_ID=$(curl -k -s -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$TARGET_REALM/client-scopes" | jq -r --arg name "$SCOPE_NAME" '.[] | select(.name == $name) | .id')
        
        if [ -n "$SCOPE_ID" ] && [ "$SCOPE_ID" != "null" ]; then
          UPDATE_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X PUT "$KC_URL/admin/realms/$TARGET_REALM/client-scopes/$SCOPE_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$PROCESSED_JSON")
          
          if [ "$UPDATE_CODE" -ge 400 ]; then
            echo "Failed to update client scope $SCOPE_NAME. HTTP $UPDATE_CODE" >&2
            exit 1
          fi
          echo "Client scope $SCOPE_NAME updated successfully."
        else
          echo "Error: Could not find ID for existing client scope $SCOPE_NAME" >&2
          exit 1
        fi
      elif [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -ne 409 ]; then
        echo "Failed to import client scope from ${each.value}. HTTP $HTTP_CODE" >&2
        ERROR_RESPONSE=$(curl -k -s -X POST "$KC_URL/admin/realms/$TARGET_REALM/client-scopes" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "$PROCESSED_JSON")
        echo "Error response: $ERROR_RESPONSE" >&2
        exit 1
      else
        echo "Custom OID4VC client scope from ${each.value} imported successfully."
        SCOPE_ID=$(curl -k -s -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$TARGET_REALM/client-scopes" | jq -r --arg name "$SCOPE_NAME" '.[] | select(.name == $name) | .id')
      fi
      
      if [ "$STATUS_LIST_ENABLED" != "true" ] && [ -n "$SCOPE_ID" ] && [ "$SCOPE_ID" != "null" ]; then
        echo "Status list is disabled. Removing status list mappers from $SCOPE_NAME..."
        MAPPER_IDS=$(curl -k -s -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$TARGET_REALM/client-scopes/$SCOPE_ID" | jq -r '.protocolMappers[]? | select(.protocolMapper == "oid4vc-status-list-claim-mapper") | .id')
        
        if [ -n "$MAPPER_IDS" ]; then
          echo "$MAPPER_IDS" | while read -r MAPPER_ID; do
            if [ -n "$MAPPER_ID" ] && [ "$MAPPER_ID" != "null" ]; then
              DELETE_CODE=$(curl -k -s -o /dev/null -w "%%{http_code}" -X DELETE "$KC_URL/admin/realms/$TARGET_REALM/client-scopes/$SCOPE_ID/protocol-mappers/models/$MAPPER_ID" \
                -H "Authorization: Bearer $TOKEN")
              
              if [ "$DELETE_CODE" -ge 400 ]; then
                echo "Warning: Failed to delete status list mapper $MAPPER_ID from $SCOPE_NAME. HTTP $DELETE_CODE" >&2
              else
                echo "Deleted status list mapper $MAPPER_ID from $SCOPE_NAME."
              fi
            fi
          done
        fi
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
}

