terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

resource "keycloak_realm" "oid4vc_vci" {
  realm       = var.realm
  enabled     = true
  login_theme = var.login_theme

  attributes = {
    preAuthorizedCodeLifespanS = var.pre_authorized_code_lifespanS
    status-list-server-url     = var.status_list_server_url
    status-list-enabled        = var.status_list_enabled
  }
}

resource "null_resource" "enable_verifiable_credentials" {
  triggers = {
    realm_id = keycloak_realm.oid4vc_vci.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      TOKEN=$(curl -s -k -X POST "${var.keycloak_url}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=${var.admin_password}" \
        -d "grant_type=password" | jq -r .access_token)

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Failed to obtain admin token" >&2
        exit 1
      fi

      CURRENT_CONFIG=$(curl -s -k -X GET "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")
        
      ENABLED=$(echo "$CURRENT_CONFIG" | jq -r '.verifiableCredentialsEnabled')
      
      if [ "$ENABLED" = "true" ]; then
        echo "Verifiable Credentials already enabled (idempotent)."
        exit 0
      fi
      
      NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq '.verifiableCredentialsEnabled = true')

      HTTP_CODE=$(curl -s -k -o /dev/null -w "%%{http_code}" -X PUT "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data "$NEW_CONFIG")
        
      if [ "$HTTP_CODE" -ge 400 ]; then
        echo "Failed to update realm. HTTP $HTTP_CODE" >&2
        exit 1
      fi

      echo "Verifiable Credentials enabled for realm ${var.realm}"
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Optionally update sd-jwt authenticator VCT via admin REST API
resource "null_resource" "update_sdjwt_vct" {

  depends_on = [
    keycloak_realm.oid4vc_vci,
    null_resource.enable_verifiable_credentials
  ]

  triggers = {
    realm_name = var.realm
    vct_value  = var.sdjwt_vct
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e

      KC_ADMIN_USER="admin"
      KC_ADMIN_PASS="${var.admin_password}"
      KC_URL="${var.keycloak_url}"
      REALM="${var.realm}"
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

      FLOW=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$REALM/authentication/flows" | jq -c --arg A "$FLOW_ALIAS" '.[] | select(.alias == $A)')
      if [ -z "$FLOW" ]; then
        echo "Flow $FLOW_ALIAS not found; skipping."
        exit 0
      fi

      FLOW_ALIAS_ENC=$(printf '%s' "$FLOW_ALIAS" | jq -sRr @uri)
      EXECS=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS_ENC/executions")
      EXEC=$(echo "$EXECS" | jq -c --arg P "$AUTH_PROVIDER_ID" '.[] | select(.providerId == $P or .authenticator == $P)' | head -n1)
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
