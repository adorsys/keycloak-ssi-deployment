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

      echo "Enabling Verifiable Credentials for realm ${var.realm}..."

      # Fetch current realm config
      # We use a strategic merge patch or simple PUT.
      # Since we only want to enable this feature, we can try to PUT the payload with just this field?
      # No, PUT replaces the realm. We must be careful.
      # Keycloak Admin API usually allows partial updates via PUT if we fetch first? Or maybe not.
      # Safer to Fetch -> Modify -> Put. But that's hard in bash.
      # Does Keycloak have a PATCH endpoint? Not standardly documented for Realms.
      # BUT, if we use the Terraform resource, it does a GET then PUT.
      # The problem is Terraform doesn't know about this field.

      # Since we know the realm is managed by Terraform, but Terraform ignores this field,
      # if we set it, Terraform might unset it on next apply?
      # Only if Terraform tracks it. If it ignores it, it stays.

      # We will attempt to update it.
      # We assume the user wants this ON.
      
      # We just send a PUT with the field. Keycloak might merge or might complain about missing fields.
      # Let's try to get the realm, add the field, and PUT it back? Too complex for one-liner.
      
      # Wait, does the Terraform provider support `extra_config`? No.
      
      # We will rely on Keycloak's behavior: usually, updating a specific component or just sending the partial representation IS NOT SUPPORTED for Realms endpoint (it replaces).
      
      # HOWEVER, maybe we can use specific endpoint? No.
      
      # Let's try to just use kcadm.sh logic: kcadm update realms/oid4vc-vci -s verifiableCredentialsEnabled=true
      # But we don't have kcadm.sh guaranteed here (terraform runs in container? no, wrapper).
      # The wrapper has kcadm.sh available.
      # JS parsing in bash with jq.
      
      CURRENT_CONFIG=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")
        
      NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq '.verifiableCredentialsEnabled = true')
      
      # Write to temp file
      echo "$NEW_CONFIG" > realm_update.json
      
      curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @realm_update.json
        
      rm realm_update.json
      echo "Verifiable Credentials enabled."
    EOT
    interpreter = ["bash", "-c"]
  }
}
