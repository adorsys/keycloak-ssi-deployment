terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

# Check if realm already exists 
resource "null_resource" "check_realm_exists" {
  triggers = {
    realm_name = var.realm
  }

  provisioner "local-exec" {
    command     = <<-EOT
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

      # Check if realm exists (don't fail if it doesn't)
      HTTP_CODE=$(curl -s -k -o /dev/null -w "%%{http_code}" \
        -X GET "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")

      if [ "$HTTP_CODE" -eq 200 ]; then
        echo "✓ Realm ${var.realm} already exists - Terraform will update it (idempotent)"
      elif [ "$HTTP_CODE" -eq 404 ]; then
        echo "✓ Realm ${var.realm} does not exist - Terraform will create it"
      else
        echo "⚠ Unexpected response checking realm: HTTP $HTTP_CODE (continuing anyway)"
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
}


# - If realm doesn't exist: Creates it
resource "keycloak_realm" "oid4vc_vci" {
  realm       = var.realm
  enabled     = true
  login_theme = var.login_theme
  # browser_flow will be set after authentication flow is created (via null_resource)

  attributes = {
    preAuthorizedCodeLifespanS   = var.pre_authorized_code_lifespanS
    status-list-server-url       = var.status_list_server_url
    browser-cors-allowed-headers = "oauth-client-attestation-pop"
  }

  depends_on = [null_resource.check_realm_exists]

  # Lifecycle: update existing realm instead of recreating
  lifecycle {
    # If realm exists, update it instead of failing
    create_before_destroy = false
    # Ignore browser_flow changes initially - we'll set it via REST API
    ignore_changes = [browser_flow]
  }
}

# Create authentication flow AFTER realm exists
# Keycloak provider automatically handles idempotency: updates if exists, creates if not
resource "keycloak_authentication_flow" "browser_with_oid4vp" {
  realm_id    = keycloak_realm.oid4vc_vci.realm
  alias       = "browser-with-oid4vp"
  provider_id = "basic-flow"

  # Ensure realm exists before creating flow
  depends_on = [keycloak_realm.oid4vc_vci]
}

# Update realm to set browser_flow after flow is created
# We use REST API because we can't update browser_flow attribute directly after creation
resource "null_resource" "set_realm_browser_flow" {
  triggers = {
    realm_id   = keycloak_realm.oid4vc_vci.id
    flow_alias = keycloak_authentication_flow.browser_with_oid4vp.alias
    flow_id    = keycloak_authentication_flow.browser_with_oid4vp.id
  }

  depends_on = [keycloak_realm.oid4vc_vci, keycloak_authentication_flow.browser_with_oid4vp]

  provisioner "local-exec" {
    command     = <<-EOT
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

      # Get current realm config
      CURRENT_CONFIG=$(curl -s -k -X GET "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN")

      # Check if browser_flow is already set correctly
      CURRENT_FLOW=$(echo "$CURRENT_CONFIG" | jq -r '.browserFlow // empty')
      if [ "$CURRENT_FLOW" = "${keycloak_authentication_flow.browser_with_oid4vp.alias}" ]; then
        echo "Browser flow already set to ${keycloak_authentication_flow.browser_with_oid4vp.alias}"
        exit 0
      fi

      # Update realm with browser_flow
      UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg flow "${keycloak_authentication_flow.browser_with_oid4vp.alias}" '.browserFlow = $flow')

      HTTP_CODE=$(curl -s -k -o /dev/null -w "%%{http_code}" -X PUT "${var.keycloak_url}/admin/realms/${var.realm}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data "$UPDATED_CONFIG")

      if [ "$HTTP_CODE" -ge 400 ]; then
        echo "Failed to set browser flow. HTTP $HTTP_CODE" >&2
        exit 1
      fi

      echo "Browser flow set to ${keycloak_authentication_flow.browser_with_oid4vp.alias}"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Enable verifiable credentials feature via REST API (not available in Terraform provider)
resource "null_resource" "enable_verifiable_credentials" {
  triggers = {
    realm_id = keycloak_realm.oid4vc_vci.id
    # Re-run if realm changes
    realm_config = jsonencode({
      realm = var.realm
      url   = var.keycloak_url
    })
  }

  # Wait for realm to be fully created and browser flow to be set
  depends_on = [
    keycloak_realm.oid4vc_vci,
    null_resource.set_realm_browser_flow
  ]

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

# Authentication flow executions - must be created after the flow exists
resource "keycloak_authentication_execution" "cookie" {
  realm_id          = var.realm
  parent_flow_alias = keycloak_authentication_flow.browser_with_oid4vp.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10

  depends_on = [keycloak_authentication_flow.browser_with_oid4vp]
}

resource "keycloak_authentication_execution" "idp_redirector" {
  realm_id          = var.realm
  parent_flow_alias = keycloak_authentication_flow.browser_with_oid4vp.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 20

  depends_on = [keycloak_authentication_flow.browser_with_oid4vp]
}

# The "Login Subflow" that offers both Forms and OID4VP
resource "keycloak_authentication_subflow" "login_selection_subflow" {
  realm_id          = var.realm
  alias             = "login-selection-flow"
  parent_flow_alias = keycloak_authentication_flow.browser_with_oid4vp.alias
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 30

  depends_on = [keycloak_authentication_flow.browser_with_oid4vp]
}

resource "keycloak_authentication_execution" "user_password_form" {
  realm_id          = var.realm
  parent_flow_alias = keycloak_authentication_subflow.login_selection_subflow.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10

  depends_on = [keycloak_authentication_subflow.login_selection_subflow]
}

# The OID4VP Authentication Execution
resource "keycloak_authentication_execution" "sdjwt_authenticator" {
  realm_id          = var.realm
  parent_flow_alias = keycloak_authentication_subflow.login_selection_subflow.alias
  authenticator     = "sd-jwt-authenticator"
  requirement       = "ALTERNATIVE"
  priority          = 20

  depends_on = [keycloak_authentication_subflow.login_selection_subflow]
}

resource "keycloak_authentication_execution_config" "sdjwt_config" {
  realm_id     = var.realm
  execution_id = keycloak_authentication_execution.sdjwt_authenticator.id
  alias        = "sdjwt-auth-config"

  config = {
    vct                     = var.sdjwt_vct
    enforceRevocationStatus = "false"
    kbJwtMaxAge             = "60"
    requireNbfClaim         = "false"
    requireExpClaim         = "false"
    "sd-jwt_alg_values"     = "ES256"
  }

  depends_on = [keycloak_authentication_execution.sdjwt_authenticator]
}
