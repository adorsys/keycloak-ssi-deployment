terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.3.0"
    }
  }
}

locals {
  rsa_issuer_key_json = templatefile("${path.root}/jsons/keys/rsa-issuer-key.json", {
    keystore_password = var.keystore_password
    keystore_path     = var.keystore_path
  })
  
  rsa_encryption_key_json = templatefile("${path.root}/jsons/keys/rsa-encryption-key.json", {
    keystore_password = var.keystore_password
    keystore_path     = var.keystore_path
  })
  
  ecdsa_issuer_key_json = templatefile("${path.root}/jsons/keys/ecdsa-issuer-key.json", {
    keystore_password = var.keystore_password
    keystore_path     = var.keystore_path
  })
}

resource "null_resource" "apply_custom_oid4vc_key_components" {
  depends_on = [var.realm_id]

  triggers = {
    oid4vc_key_components_hash = join(",", [local.rsa_issuer_key_json, local.rsa_encryption_key_json, local.ecdsa_issuer_key_json])
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
      echo "Importing OID4VC key components via curl..."
      
      # Import RSA issuer key
      echo '${local.rsa_issuer_key_json}' | curl -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      
      # Import RSA encryption key
      echo '${local.rsa_encryption_key_json}' | curl -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      
      # Import ECDSA issuer key
      echo '${local.ecdsa_issuer_key_json}' | curl -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      
      echo "Custom OID4VC key components imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}
