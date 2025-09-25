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

resource "keycloak_openid_client" "test_client" {
  realm_id                     = var.realm_id
  client_id                    = "oid4vc-demo-public"
  name                         = "oid4vc-demo-public"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  root_url                     = var.test_client_url
  base_url                     = var.test_client_url
  valid_redirect_uris = [
    "${var.test_client_url}/*"
  ]
  web_origins = [
    var.test_client_url
  ]
}

resource "null_resource" "apply_test_client_attributes" {
  depends_on = [keycloak_openid_client.test_client]

  triggers = {
    client_id = keycloak_openid_client.test_client.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      CLIENT_CFG=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/clients/${keycloak_openid_client.test_client.id}" -H "Authorization: Bearer $TOKEN")

      UPDATED=$(echo "$CLIENT_CFG" | jq --arg URL "${var.test_client_url}" '.attributes += {"oid4vci.enabled":"true","post.logout.redirect.uris": ($URL+"##"+$URL+"/*") }')

      curl -s -k -X PUT "$KC_URL/admin/realms/$REALM/clients/${keycloak_openid_client.test_client.id}" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$UPDATED" > /dev/null

      echo "oid4vc-demo-public attributes applied."
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Attach optional client scopes to oid4vc-demo-public
resource "null_resource" "attach_optional_scopes_public" {
  depends_on = [null_resource.apply_test_client_attributes]

  triggers = {
    client_id = keycloak_openid_client.test_client.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      # Get client internal ID by clientId
      CLIENT_ID=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/clients?clientId=${keycloak_openid_client.test_client.client_id}" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

      attach_scope() {
        SCOPE_NAME=$1
        SCOPE_ID=$(curl -s -k -X GET "$KC_URL/admin/realms/$REALM/client-scopes" \
          -H "Authorization: Bearer $TOKEN" | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")
        curl -s -k -X PUT "$KC_URL/admin/realms/$REALM/clients/$CLIENT_ID/optional-client-scopes/$SCOPE_ID" \
          -H "Authorization: Bearer $TOKEN"
        echo "Attached optional scope: $SCOPE_NAME"
      }

      attach_scope "IdentityCredential"
      attach_scope "SteuerberaterCredential"
      attach_scope "KMACredential"

      echo "All optional scopes attached to oid4vc-demo-public."
    EOT
    interpreter = ["bash", "-c"]
  }
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

# Optionally update sd-jwt authenticator VCT via admin REST API
resource "null_resource" "update_sdjwt_vct" {
  depends_on = [null_resource.attach_optional_scopes]

  triggers = {
    realm_name = var.realm_name
    vct_value  = var.sdjwt_vct
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm_name}"
      FLOW_ALIAS="oid4vp auth"
      AUTH_PROVIDER_ID="sd-jwt-authenticator"
      CONFIG_ALIAS="sdjwt-auth-config"
      VCT_VALUE="${var.sdjwt_vct}"

      TOKEN=$(curl -s -k -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" -d "username=$KC_ADMIN_USER" -d "password=$KC_ADMIN_PASS" -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      FLOW=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$REALM/authentication/flows" | jq -c ".[] | select(.alias==\"$FLOW_ALIAS\")")
      if [ -z "$FLOW" ]; then
        echo "Flow $FLOW_ALIAS not found; skipping."
        exit 0
      fi

      FLOW_ALIAS_ENC=$(printf '%s' "$FLOW_ALIAS" | jq -sRr @uri)
      EXECS=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS_ENC/executions")
      EXEC=$(echo "$EXECS" | jq -c ".[] | select(.providerId==\"$AUTH_PROVIDER_ID\" or .authenticator==\"$AUTH_PROVIDER_ID\")" | head -n1)
      if [ -z "$EXEC" ]; then
        echo "Execution for $AUTH_PROVIDER_ID not found; skipping."
        exit 0
      fi

      EXEC_ID=$(echo "$EXEC" | jq -r .id)
      CFG_ID=$(echo "$EXEC" | jq -r .authenticationConfig)

      if [ "$CFG_ID" != "null" ] && [ -n "$CFG_ID" ]; then
        CFG=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$REALM/authentication/config/$CFG_ID")
        NEW_CFG=$(echo "$CFG" | jq --arg V "$VCT_VALUE" '.config.vct = $V')
        curl -s -k -X PUT "$KC_URL/admin/realms/$REALM/authentication/config/$CFG_ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$NEW_CFG" > /dev/null
      else
        BODY=$(jq -n \
          --arg alias "$CONFIG_ALIAS" \
          --arg V "$VCT_VALUE" \
          '{ alias: $alias, config: { vct: $V, enforceNbfClaim: "false", enforceExpClaim: "false", kbJwtMaxAge: "60" } }')
        curl -s -k -X POST "$KC_URL/admin/realms/$REALM/authentication/executions/$EXEC_ID/config" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$BODY" > /dev/null
      fi

      echo "sd-jwt authenticator VCT ensured."
    EOT
    interpreter = ["bash", "-c"]
  }
}
