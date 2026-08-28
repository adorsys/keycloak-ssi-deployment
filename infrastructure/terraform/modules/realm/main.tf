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

  attributes = merge(
    {
      preAuthorizedCodeLifespanS = var.pre_authorized_code_lifespanS
      status-list-server-url     = var.status_list_server_url
      status-list-enabled        = var.status_list_enabled
    },
    trimspace(var.oid4vci_display) != "" ? {
      "oid4vci.display" = var.oid4vci_display
    } : {}
  )
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

data "keycloak_authentication_execution" "oid4vp" {
  realm_id          = keycloak_realm.oid4vc_vci.id
  parent_flow_alias = "oid4vp auth"
  provider_id       = "oid4vp-authenticator"
  depends_on        = [null_resource.enable_verifiable_credentials]
}

resource "keycloak_authentication_execution_config" "config" {
  realm_id     = keycloak_realm.oid4vc_vci.id
  execution_id = data.keycloak_authentication_execution.oid4vp.id
  alias        = "oid4vp-config-alias"

  config = merge(
    {
      credentialTypes                    = var.oid4vp_credential_types
      clientIdentifierPrefix             = var.oid4vp_client_identifier_prefix
      responseMode                       = var.oid4vp_response_mode
      requestUriMethod                   = var.oid4vp_request_uri_method
      customUrlScheme                    = var.oid4vp_custom_url_scheme
      requireCryptographicHolderBinding  = var.oid4vp_require_cryptographic_holder_binding
      holderBindingProofMaxAge           = var.oid4vp_holder_binding_proof_max_age
      requireNbfClaim                    = var.oid4vp_require_nbf_claim
      requireExpClaim                    = var.oid4vp_require_exp_claim
      verifyIssuerClaim                  = var.oid4vp_verify_issuer_claim
      fallbackToIsoSpecSessionTranscript = var.oid4vp_fallback_to_iso_spec_session_transcript
      enforceRevocationStatus            = var.oid4vp_enforce_revocation_status
    },
    trimspace(var.oid4vp_authentication_profiles) != "" ? {
      profiles = var.oid4vp_authentication_profiles
    } : {},
    trimspace(var.oid4vp_access_certificate) != "" ? {
      accessCertificate = var.oid4vp_access_certificate
    } : {},
    trimspace(var.oid4vp_registration_certificate) != "" ? {
      registrationCertificate = var.oid4vp_registration_certificate
    } : {},
    trimspace(var.oid4vp_transaction_data) != "" ? {
      transactionData = var.oid4vp_transaction_data
    } : {},
    trimspace(var.oid4vp_verifier_info) != "" ? {
      verifierInfo = var.oid4vp_verifier_info
    } : {}
  )
}
