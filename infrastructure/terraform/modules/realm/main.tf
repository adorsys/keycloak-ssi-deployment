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
      preAuthorizedCodeLifespanS                     = var.pre_authorized_code_lifespanS
      status-list-server-url                         = var.status_list_server_url
      status-list-enabled                            = var.status_list_enabled
      "oid4vci.allow_proof_iss_mismatch"             = tostring(var.oid4vci_allow_proof_iss_mismatch)
      "oid4vci.omit_encryption_metadata"             = tostring(var.oid4vci_omit_encryption_metadata)
      "oid4vci.patch_credential_requests"            = tostring(var.oid4vci_patch_credential_requests)
      "oid4vci.patch_metadata_x5c_to_leaf_cert_only" = tostring(var.oid4vci_patch_metadata_x5c_to_leaf_cert_only)
    },
    trimspace(var.oid4vci_display) != "" ? {
      "oid4vci.display" = var.oid4vci_display
    } : {},
    trimspace(var.oid4vci_signed_metadata_alg) != "" ? {
      "oid4vci.signed_metadata.alg" = var.oid4vci_signed_metadata_alg
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
    } : {},
    var.oid4vp_import_unknown_users ? {
      importUnknownUsers          = "true"
      importIdentityProviderAlias = var.oid4vp_import_identity_provider_alias
    } : {}
  )
}

resource "null_resource" "oid4vp_import_identity_provider" {
  count = var.oid4vp_import_unknown_users ? 1 : 0

  triggers = {
    realm_id              = keycloak_realm.oid4vc_vci.id
    alias                 = var.oid4vp_import_identity_provider_alias
    provider              = "oid4vp-plugin-import"
    mapper_config_version = "claim-paths-and-email-profile-v3"
    email_required        = tostring(var.oid4vp_user_provisioning_test_email_required)
    mappers = jsonencode([
      { name = "Given name", claim = "eu\\.europa\\.ec\\.eudi\\.pid\\.1.given_name", attribute = "firstName" },
      { name = "Family name", claim = "eu\\.europa\\.ec\\.eudi\\.pid\\.1.family_name", attribute = "lastName" },
      { name = "Birth date", claim = "eu\\.europa\\.ec\\.eudi\\.pid\\.1.birth_date", attribute = "birthdate" }
    ])
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../../scripts/configure-oid4vp-import-provider.sh"

    environment = {
      KEYCLOAK_BASE_URL            = var.keycloak_url
      KEYCLOAK_REALM               = var.realm
      KEYCLOAK_ADMIN_NAME          = "admin"
      KEYCLOAK_ADMIN_SECRET        = var.oid4vp_import_admin_password
      OID4VP_IMPORT_ALIAS          = var.oid4vp_import_identity_provider_alias
      OID4VP_IMPORT_MAPPERS        = self.triggers.mappers
      OID4VP_IMPORT_EMAIL_REQUIRED = self.triggers.email_required
    }
  }
}
