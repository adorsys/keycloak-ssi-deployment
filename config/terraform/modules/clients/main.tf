terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

resource "keycloak_openid_client" "openid4vc_rest_api" {
  realm_id                     = var.realm_id
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

resource "null_resource" "apply_client_attributes" {
  depends_on = [keycloak_openid_client.openid4vc_rest_api]

  triggers = {
    client_id = keycloak_openid_client.openid4vc_rest_api.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      KC_REALM="master"

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      CLIENT_CONFIG=$(curl -s -k -X GET "$KC_URL/admin/realms/${var.realm_name}/clients/${keycloak_openid_client.openid4vc_rest_api.id}" \
        -H "Authorization: Bearer $TOKEN")

      curl -s -k -X PUT "$KC_URL/admin/realms/${var.realm_name}/clients/${keycloak_openid_client.openid4vc_rest_api.id}" \
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

resource "null_resource" "attach_optional_scopes" {
  depends_on = [null_resource.apply_client_attributes]

  triggers = {
    client_id = keycloak_openid_client.openid4vc_rest_api.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      KC_REALM="master"

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      # Get client internal ID
      CLIENT_ID=$(curl -s -k -X GET "$KC_URL/admin/realms/${var.realm_name}/clients?clientId=${keycloak_openid_client.openid4vc_rest_api.client_id}" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

      attach_scope() {
        SCOPE_NAME=$1
        SCOPE_ID=$(curl -s -k -X GET "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
          -H "Authorization: Bearer $TOKEN" | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")
        curl -s -k -X PUT "$KC_URL/admin/realms/${var.realm_name}/clients/$CLIENT_ID/optional-client-scopes/$SCOPE_ID" \
          -H "Authorization: Bearer $TOKEN"
        echo "Attached optional scope: $SCOPE_NAME"
      }

      # Attach the custom scopes
      attach_scope "IdentityCredential"
      attach_scope "SteuerberaterCredential"
      attach_scope "KMACredential"

      echo "All optional scopes attached successfully."
    EOT
    interpreter = ["bash", "-c"]
  }
}
