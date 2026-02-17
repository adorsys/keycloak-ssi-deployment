terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

resource "keycloak_realm" "oid4vc_vci" {
  realm   = var.realm
  enabled = true
  attributes = {
    preAuthorizedCodeLifespanS = var.pre_authorized_code_lifespanS
    status-list-server-url     = var.status_list_server_url
    status-list-enabled        = "false"
  }
}

resource "null_resource" "enable_verifiable_credentials" {
  triggers = {
    realm_id = keycloak_realm.oid4vc_vci.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

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

      CURRENT_CONFIG=$(curl -s -k -X GET "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")
        
      ENABLED=$(echo "$CURRENT_CONFIG" | jq -r '.verifiableCredentialsEnabled')
      
      if [ "$ENABLED" = "true" ]; then
        echo "Verifiable Credentials already enabled (idempotent)."
        exit 0
      fi
      
      NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq '.verifiableCredentialsEnabled = true')

      HTTP_CODE=$(curl -s -k -o /dev/null -w "%%{http_code}" -X PUT "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data "$NEW_CONFIG")
        
      if [ "$HTTP_CODE" -ge 400 ]; then
        echo "Failed to update realm. HTTP $HTTP_CODE" >&2
        exit 1
      fi

      echo "Verifiable Credentials enabled for realm ${var.realm}"
    EOT
    
    interpreter = ["bash", "-c"]
  }
}
