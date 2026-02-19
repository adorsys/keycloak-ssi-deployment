terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  saml_idp_config_json = file("${path.root}/jsons/identity_providers/saml-idp-config.json")
}

# Wait for realm to be ready before importing SAML IdP
resource "null_resource" "wait_for_realm_saml" {
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

resource "null_resource" "apply_saml_identity_provider" {
  depends_on = [null_resource.wait_for_realm_saml]

  triggers = {
    saml_idp_config_hash = sha256(local.saml_idp_config_json)
    realm_id             = var.realm_id
    realm_name           = var.realm_name
    keycloak_url         = var.keycloak_url
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

      echo "Importing SAML Identity Provider..."

      # Parse the JSON to extract identity providers and mappers
      IDP_CONFIG=$(echo '${local.saml_idp_config_json}' | jq '.identityProviders[0]')
      MAPPERS_CONFIG=$(echo '${local.saml_idp_config_json}' | jq '.identityProviderMappers')

      # Import SAML Identity Provider
      IDP_HTTP_CODE=$(echo "$IDP_CONFIG" | curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/identity-provider/instances" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-)
      
      if [ "$IDP_HTTP_CODE" -ge 400 ] && [ "$IDP_HTTP_CODE" -ne 409 ]; then
        echo "Failed to import SAML Identity Provider. HTTP $IDP_HTTP_CODE" >&2
        exit 1
      fi

      if [ "$IDP_HTTP_CODE" -eq 409 ]; then
        echo "SAML Identity Provider already exists (HTTP 409)."
      else
        echo "SAML Identity Provider imported successfully."
      fi

      # Import Identity Provider Mappers
      echo "Importing SAML Identity Provider Mappers..."

      # Get the identity provider ID
      IDP_ALIAS=$(echo "$IDP_CONFIG" | jq -r '.alias')
      IDP_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/$TARGET_REALM/identity-provider/instances" \
        -H "Authorization: Bearer $TOKEN" | jq -r ".[] | select(.alias==\"$IDP_ALIAS\") | .internalId")

      if [ -z "$IDP_ID" ] || [ "$IDP_ID" = "null" ]; then
        echo "Failed to find SAML Identity Provider ID for alias $IDP_ALIAS" >&2
        exit 1
      fi

      # Import each mapper
      echo "$MAPPERS_CONFIG" | jq -c '.[]' | while read -r mapper; do
        MAPPER_NAME=$(echo "$mapper" | jq -r '.name')
        MAPPER_HTTP_CODE=$(echo "$mapper" | curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$KC_URL/admin/realms/$TARGET_REALM/identity-provider/instances/$IDP_ID/mappers" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-)
        
        if [ "$MAPPER_HTTP_CODE" -ge 400 ] && [ "$MAPPER_HTTP_CODE" -ne 409 ]; then
          echo "Failed to import mapper $MAPPER_NAME. HTTP $MAPPER_HTTP_CODE" >&2
          exit 1
        fi
        
        if [ "$MAPPER_HTTP_CODE" -eq 409 ]; then
          echo "Mapper $MAPPER_NAME already exists (HTTP 409)."
        else
          echo "Mapper $MAPPER_NAME imported successfully."
        fi
      done

      echo "SAML Identity Provider and Mappers configuration completed."
    EOT
    interpreter = ["bash", "-c"]
  }
}
