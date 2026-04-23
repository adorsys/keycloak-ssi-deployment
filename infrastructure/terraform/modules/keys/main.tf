terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  rsa_issuer_key_json     = var.enable_rsa_keys ? file("${path.root}/jsons/keys/rsa-issuer-key.json") : ""
  rsa_encryption_key_json = var.enable_rsa_keys ? file("${path.root}/jsons/keys/rsa-encryption-key.json") : ""
  ecdsa_issuer_key_json   = file("${path.root}/jsons/keys/ecdsa-issuer-key.json")
}

resource "null_resource" "apply_custom_oid4vc_key_components" {
  depends_on = [var.realm_id]

  triggers = {
    realm_id                   = var.realm_id
    enable_rsa_keys            = tostring(var.enable_rsa_keys)
    oid4vc_key_components_hash = join(",", compact([local.rsa_issuer_key_json, local.rsa_encryption_key_json, local.ecdsa_issuer_key_json]))
    oid4vc_keystore_path       = var.oid4vc_keystore_path
    oid4vc_keystore_password   = var.oid4vc_keystore_password
    oid4vc_keystore_type       = var.oid4vc_keystore_type
    oid4vc_ecdsa_key_alias     = var.oid4vc_ecdsa_key_alias
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

      if [ "${var.enable_rsa_keys}" = "true" ]; then
        # Import RSA issuer key
        echo '${local.rsa_issuer_key_json}' | jq --arg realm "${var.realm_name}" '.parentId = $realm' | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-

        # Import RSA encryption key
        echo '${local.rsa_encryption_key_json}' | jq --arg realm "${var.realm_name}" '.parentId = $realm' | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-
      fi

      # Build the target ECDSA java-keystore provider payload once.
      ECDSA_PROVIDER_PAYLOAD=$(echo '${local.ecdsa_issuer_key_json}' | jq -c \
        --arg realm "${var.realm_name}" \
        --arg keystore "${var.oid4vc_keystore_path}" \
        --arg keystorePassword "${var.oid4vc_keystore_password}" \
        --arg keystoreType "${var.oid4vc_keystore_type}" \
        --arg keyAlias "${var.oid4vc_ecdsa_key_alias}" \
        '.parentId = $realm
        | .providerId = "java-keystore"
        | .config = {
            "keystorePassword": [$keystorePassword],
            "keyAlias": [$keyAlias],
            "keyPassword": [$keystorePassword],
            "keystoreType": [$keystoreType],
            "active": ["true"],
            "keystore": [$keystore],
            "priority": ["200"],
            "enabled": ["true"],
            "algorithm": ["ES256"]
          }')

      # Keep a single ES256 java-keystore component:
      # - create one if missing
      # - update the first existing one in place (stable provider id / kid behavior)
      # - delete any extras
      EXISTING_ES256_JKS_COMPONENT_IDS=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components?type=org.keycloak.keys.KeyProvider" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r '.[] | select(.providerId == "java-keystore" and ((.config.algorithm[0] // "") == "ES256")) | .id')

      PRIMARY_ES256_JKS_COMPONENT_ID=$(echo "$EXISTING_ES256_JKS_COMPONENT_IDS" | rg -v '^$' | awk 'NR==1')

      if [ -z "$PRIMARY_ES256_JKS_COMPONENT_ID" ]; then
        echo "No ES256 java-keystore provider found. Creating configured provider."
        echo "$ECDSA_PROVIDER_PAYLOAD" | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/components" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @- >/dev/null
      else
        echo "Updating existing ES256 java-keystore provider in place... ID=$PRIMARY_ES256_JKS_COMPONENT_ID"
        EXISTING_COMPONENT=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components/$PRIMARY_ES256_JKS_COMPONENT_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")
        UPDATED_COMPONENT=$(echo "$EXISTING_COMPONENT" | jq \
          --arg keystore "${var.oid4vc_keystore_path}" \
          --arg keystorePassword "${var.oid4vc_keystore_password}" \
          --arg keystoreType "${var.oid4vc_keystore_type}" \
          --arg keyAlias "${var.oid4vc_ecdsa_key_alias}" \
          '.providerId = "java-keystore"
          | .config.keystorePassword = [$keystorePassword]
          | .config.keyAlias = [$keyAlias]
          | .config.keyPassword = [$keystorePassword]
          | .config.keystoreType = [$keystoreType]
          | .config.active = ["true"]
          | .config.keystore = [$keystore]
          | .config.priority = ["200"]
          | .config.enabled = ["true"]
          | .config.algorithm = ["ES256"]')
        echo "$UPDATED_COMPONENT" | curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$PRIMARY_ES256_JKS_COMPONENT_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @- >/dev/null
      fi

      EXTRA_ES256_JKS_COMPONENT_IDS=$(echo "$EXISTING_ES256_JKS_COMPONENT_IDS" | rg -v '^$' | awk 'NR>1')
      if [ -n "$EXTRA_ES256_JKS_COMPONENT_IDS" ]; then
        while IFS= read -r COMP_ID; do
          [ -z "$COMP_ID" ] && continue
          echo "Deleting duplicate ES256 java-keystore provider... ID=$COMP_ID"
          curl -k -s -X DELETE "$KC_URL/admin/realms/${var.realm_name}/components/$COMP_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" >/dev/null
        done <<< "$EXTRA_ES256_JKS_COMPONENT_IDS"
      fi

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

    # Always disable generated ES256 providers so only the persistent
    # java-keystore-backed ECDSA key is used.
    ECDSA_GENERATED_COMPONENT_IDS=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components?type=org.keycloak.keys.KeyProvider" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq -r '.[] | select(.providerId == "ecdsa-generated") | .id')

    if [ -n "$ECDSA_GENERATED_COMPONENT_IDS" ]; then
      while IFS= read -r COMP_ID; do
        [ -z "$COMP_ID" ] && continue
        echo "Disabling generated ECDSA key provider... ID=$COMP_ID"

        COMPONENT=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components/$COMP_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")

        UPDATED_COMPONENT=$(echo "$COMPONENT" | jq '.config.active = ["false"] | .config.enabled = ["false"]')

        echo "$UPDATED_COMPONENT" | curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$COMP_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-
      done <<< "$ECDSA_GENERATED_COMPONENT_IDS"
    fi

    if [ "${var.enable_rsa_keys}" = "false" ]; then
      # Disable all RSA encryption key providers (legacy or custom)
      RSA_ENC_COMPONENT_IDS=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components?type=org.keycloak.keys.KeyProvider" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -r '.[] | select(((.providerId // "") | test("rsa-enc"; "i")) or ((.config.algorithm // []) | index("RSA-OAEP") != null)) | .id')

      if [ -n "$RSA_ENC_COMPONENT_IDS" ]; then
        while IFS= read -r COMP_ID; do
          [ -z "$COMP_ID" ] && continue
          echo "Disabling RSA encryption key provider... ID=$COMP_ID"

          COMPONENT=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/components/$COMP_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json")

          UPDATED_COMPONENT=$(echo "$COMPONENT" | jq '.config.active = ["false"] | .config.enabled = ["false"]')

          echo "$UPDATED_COMPONENT" | curl -k -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/components/$COMP_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            --data-binary @-
        done <<< "$RSA_ENC_COMPONENT_IDS"
      fi

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
    else
      echo "enable_rsa_keys=true -> keeping RSA providers enabled."
    fi

    echo "Generated Keycloak keys disabled successfully."
  EOT
    interpreter = ["bash", "-c"]
  }

}
