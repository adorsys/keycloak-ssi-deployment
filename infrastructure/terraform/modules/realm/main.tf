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
  }
}

resource "null_resource" "enable_verifiable_credentials" {
  triggers = {
    realm_id = keycloak_realm.oid4vc_vci.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      # Obtain admin token
      TOKEN=$(curl -k -s -X POST "${var.keycloak_url}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=${var.admin_password}" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      # Enable Verifiable Credentials feature
      CURRENT_CONFIG=$(curl -k -s -X GET "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")
        
      NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq '.verifiableCredentialsEnabled = true')
      
      echo "$NEW_CONFIG" > realm_update.json
      
      curl -k -s -X PUT "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @realm_update.json
        
      rm realm_update.json
      echo "Verifiable Credentials enabled for realm ${var.realm}"
    EOT
    interpreter = ["bash", "-c"]
  }
}
