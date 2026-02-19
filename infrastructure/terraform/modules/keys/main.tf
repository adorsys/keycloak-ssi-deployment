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

# Wait for realm to be ready before importing keys
resource "null_resource" "wait_for_realm_keys" {
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
          break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
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
          break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
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

resource "null_resource" "apply_custom_oid4vc_key_components" {
  depends_on = [null_resource.wait_for_realm_keys]

  triggers = {
    realm_id                   = var.realm_id
    oid4vc_key_components_hash = join(",", [local.rsa_issuer_key_json, local.rsa_encryption_key_json, local.ecdsa_issuer_key_json])
    realm_name                 = var.realm_name
    keycloak_url               = var.keycloak_url
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"
      export TARGET_REALM="${var.realm_name}"

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

      echo "Importing OID4VC key components..."

      # Import RSA issuer key
      RSA_ISSUER_HTTP_CODE=$(echo '${local.rsa_issuer_key_json}' | curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-)
      
      if [ "$RSA_ISSUER_HTTP_CODE" -ge 400 ] && [ "$RSA_ISSUER_HTTP_CODE" -ne 409 ]; then
        echo "Failed to import RSA issuer key. HTTP $RSA_ISSUER_HTTP_CODE" >&2
        exit 1
      fi

      # Import RSA encryption key
      RSA_ENC_HTTP_CODE=$(echo '${local.rsa_encryption_key_json}' | curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-)
      
      if [ "$RSA_ENC_HTTP_CODE" -ge 400 ] && [ "$RSA_ENC_HTTP_CODE" -ne 409 ]; then
        echo "Failed to import RSA encryption key. HTTP $RSA_ENC_HTTP_CODE" >&2
        exit 1
      fi

      # Import ECDSA issuer key
      ECDSA_HTTP_CODE=$(echo '${local.ecdsa_issuer_key_json}' | curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-)
      
      if [ "$ECDSA_HTTP_CODE" -ge 400 ] && [ "$ECDSA_HTTP_CODE" -ne 409 ]; then
        echo "Failed to import ECDSA issuer key. HTTP $ECDSA_HTTP_CODE" >&2
        exit 1
      fi

      echo "Custom OID4VC key components imported successfully."
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

    # Disable RSA-OAEP
    RSA_OAEP_KID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq -r '.active."RSA-OAEP"')

    if [ "$RSA_OAEP_KID" != "null" ] && [ "$RSA_OAEP_KID" != "" ]; then
      RSA_OAEP_PROV_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid).providerId')

      if [ "$RSA_OAEP_PROV_ID" != "null" ] && [ "$RSA_OAEP_PROV_ID" != "" ]; then
        echo "Disabling generated RSA-OAEP key... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"

        RSA_OAEP_COMPONENT=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components/$RSA_OAEP_PROV_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")

        UPDATE_RSA_OAEP_COMPONENT=$(echo "$RSA_OAEP_COMPONENT" | jq '.config.active = ["false"]')

        echo "$UPDATE_RSA_OAEP_COMPONENT" | curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$RSA_OAEP_PROV_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-
      fi
    fi

    # Disable RS256
    RS256_KID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq -r '.active."RS256"')

    if [ "$RS256_KID" != "null" ] && [ "$RS256_KID" != "" ]; then
      RS256_PROV_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/keys" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid).providerId')

      if [ "$RS256_PROV_ID" != "null" ] && [ "$RS256_PROV_ID" != "" ]; then
        echo "Disabling generated RS256 key... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"

        RS256_COMPONENT=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components/$RS256_PROV_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")

        UPDATE_RS256_COMPONENT=$(echo "$RS256_COMPONENT" | jq '.config.active = ["false"]')

        echo "$UPDATE_RS256_COMPONENT" | curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$RS256_PROV_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-
      fi
    fi

    echo "Generated Keycloak keys disabled successfully."
  EOT
    interpreter = ["bash", "-c"]
  }

}
