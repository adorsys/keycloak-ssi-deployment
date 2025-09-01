terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.3.0"
    }
  }
}

resource "keycloak_openid_client" "openid4vc_rest_api" {
  realm_id                    = var.realm_id
  client_id                    = "openid4vc-rest-api"
  name                         = "openid4vc-rest-api"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  valid_redirect_uris = [
    "https://localhost:8443/callback",
    "https://issuer.eudi-adorsys.com/services/*",
    "http://back.localhost.com/*"
  ]
  web_origins = [
    "https://issuer.eudi-adorsys.com/services",
    "https://localhost:8443"
  ]
  client_secret = var.client_secret
}

resource "keycloak_openid_client_optional_scopes" "openid4vc_rest_api_optional" {
  realm_id  = var.realm_id
  client_id = keycloak_openid_client.openid4vc_rest_api.id
  optional_scopes = [
    "IdentityCredential",
    "SteuerberaterCredential"
  ]
}

resource "null_resource" "apply_client_attributes" {
  depends_on = [keycloak_openid_client.openid4vc_rest_api]

  triggers = {
    client_id = keycloak_openid_client.openid4vc_rest_api.id
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
      
      echo "Applying client attributes via API..."
      
      # Get current client configuration
      CLIENT_CONFIG=$(curl -s -X GET "$KC_URL/admin/realms/${var.realm_name}/clients/${keycloak_openid_client.openid4vc_rest_api.id}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")
      
      # Update client with additional attributes
      curl -s -X PUT "$KC_URL/admin/realms/${var.realm_name}/clients/${keycloak_openid_client.openid4vc_rest_api.id}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(echo "$CLIENT_CONFIG" | jq '.attributes += {
          "oid4vci.enabled": "true",
          "client.secret.creation.time": "1719785014",
          "post.logout.redirect.uris": "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
        }')"
      
      echo "Client attributes applied successfully."
    EOT
    interpreter = ["bash", "-c"]
  }
}
