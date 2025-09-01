terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.3.0"
    }
  }
}

locals {
  identity_credential_json = templatefile("${path.root}/jsons/scopes/client-scope-identity_credential.json", {
    realm_name = var.realm_name
  })
  
  steuerberater_credential_json = templatefile("${path.root}/jsons/scopes/client-scope-stbk_westfalen_lippe.json", {
    realm_name = var.realm_name
  })
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  depends_on = [var.realm_id]

  triggers = {
    oid4vc_client_scopes_hash = join(",", [local.identity_credential_json, local.steuerberater_credential_json])
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"
      export TOKEN=$(curl -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)
      echo "Importing OID4VC client scopes via curl..."
      
      # Import IdentityCredential scope
      echo '${local.identity_credential_json}' | curl -s -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      
      # Import SteuerberaterCredential scope
      echo '${local.steuerberater_credential_json}' | curl -s -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      
      echo "Custom OID4VC client scopes imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}
