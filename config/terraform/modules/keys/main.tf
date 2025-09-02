terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  rsa_issuer_key_json     = file("${path.root}/jsons/keys/rsa-issuer-key.json")
  rsa_encryption_key_json = file("${path.root}/jsons/keys/rsa-encryption-key.json")
  ecdsa_issuer_key_json   = file("${path.root}/jsons/keys/ecdsa-issuer-key.json")
}

resource "null_resource" "apply_custom_oid4vc_key_components" {
  depends_on = [var.realm_id]

  triggers = {
    oid4vc_key_components_hash = join(",", [local.rsa_issuer_key_json, local.rsa_encryption_key_json, local.ecdsa_issuer_key_json])
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"

      # Get admin token
      export TOKEN=$(curl -k -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      echo "Importing OID4VC key components..."

      # Import RSA issuer key
      echo '${local.rsa_issuer_key_json}' | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-

      # Import RSA encryption key
      echo '${local.rsa_encryption_key_json}' | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-

      # Import ECDSA issuer key
      echo '${local.ecdsa_issuer_key_json}' | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-

      echo "Custom OID4VC key components imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Disable automatically generated Keycloak keys (RSA-OAEP and RS256)
resource "null_resource" "disable_generated_keys" {
  depends_on = [null_resource.apply_custom_oid4vc_key_components]

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

      # Get admin token
      export TOKEN=$(curl -k -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      echo "Disabling generated Keycloak keys..."

      # Get RSA-OAEP key details and disable it
      RSA_OAEP_KID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r '.active."RSA-OAEP"')
      
      if [ "$RSA_OAEP_KID" != "null" ] && [ "$RSA_OAEP_KID" != "" ]; then
        RSA_OAEP_PROV_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
        
        if [ "$RSA_OAEP_PROV_ID" != "null" ] && [ "$RSA_OAEP_PROV_ID" != "" ]; then
          echo "Disabling generated RSA-OAEP key... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"
          curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$RSA_OAEP_PROV_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"config":{"active":["false"]}}'
        fi
      fi

      # Get RS256 key details and disable it
      RS256_KID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r '.active."RS256"')
      
      if [ "$RS256_KID" != "null" ] && [ "$RS256_KID" != "" ]; then
        RS256_PROV_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
        
        if [ "$RS256_PROV_ID" != "null" ] && [ "$RS256_PROV_ID" != "" ]; then
          echo "Disabling generated RS256 key... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"
          curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$RS256_PROV_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"config":{"active":["false"]}}'
        fi
      fi

      echo "Generated Keycloak keys disabled successfully."
    EOT
    interpreter = ["bash", "-c"]
  }
}
