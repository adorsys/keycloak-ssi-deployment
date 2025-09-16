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

resource "null_resource" "apply_saml_identity_provider" {
  depends_on = [var.realm_id]

  triggers = {
    saml_idp_config_hash = sha256(local.saml_idp_config_json)
  }

  provisioner "local-exec" {
    command     = <<-EOT
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

      echo "Importing SAML Identity Provider via curl..."

      # Parse the JSON to extract identity providers and mappers
      IDP_CONFIG=$(echo '${local.saml_idp_config_json}' | jq '.identityProviders[0]')
      MAPPERS_CONFIG=$(echo '${local.saml_idp_config_json}' | jq '.identityProviderMappers')

      # Import SAML Identity Provider
      echo "$IDP_CONFIG" | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/identity-provider/instances" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-

      echo "SAML Identity Provider imported successfully."

      # Import Identity Provider Mappers
      echo "Importing SAML Identity Provider Mappers..."

      # Get the identity provider ID
      IDP_ALIAS=$(echo "$IDP_CONFIG" | jq -r '.alias')
      IDP_ID=$(curl -k -s -X GET "$KC_URL/admin/realms/${var.realm_name}/identity-provider/instances" \
        -H "Authorization: Bearer $TOKEN" | jq -r ".[] | select(.alias==\"$IDP_ALIAS\") | .internalId")

      # Import each mapper
      echo "$MAPPERS_CONFIG" | jq -c '.[]' | while read -r mapper; do
        echo "$mapper" | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/identity-provider/instances/$IDP_ID/mappers" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @-
        echo "Mapper imported: $(echo "$mapper" | jq -r '.name')"
      done

      echo "SAML Identity Provider and Mappers imported successfully."
    EOT
    interpreter = ["bash", "-c"]
  }
}
