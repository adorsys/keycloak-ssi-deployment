locals {
  # Non-secret parts of client configuration live in code; the confidential client secret is injected at runtime.
  clients = {
    "oid4vc-demo-public" = {
      name                         = "oid4vc-demo-public"
      enabled                      = true
      access_type                  = "PUBLIC"
      standard_flow_enabled        = true
      direct_access_grants_enabled = false
      valid_redirect_uris          = var.oid4vc_demo_public_valid_redirect_uris
      web_origins                  = var.oid4vc_demo_public_web_origins
      full_scope_allowed           = true
      attributes = {
        "oid4vci.enabled"           = "true"
        "post.logout.redirect.uris" = var.oid4vc_demo_public_post_logout_redirect_uris
      }
    }
    "openid4vc-rest-api" = {
      name                         = "openid4vc-rest-api"
      enabled                      = true
      access_type                  = "CONFIDENTIAL"
      standard_flow_enabled        = true
      direct_access_grants_enabled = true
      full_scope_allowed           = true
      client_secret                = var.openid4vc_rest_api_client_secret
      valid_redirect_uris          = var.openid4vc_rest_api_valid_redirect_uris
      web_origins                  = var.openid4vc_rest_api_web_origins
      attributes = {
        "oid4vci.enabled"             = "true"
        "client.secret.creation.time" = "1719785014"
        "post.logout.redirect.uris"   = var.openid4vc_rest_api_post_logout_redirect_uris
      }
    }
  }

  # Keep authenticator VCTs aligned with selected OID4VC client scopes.
  available_scope_files = fileset("${path.root}/jsons/scopes", "*.json")
  available_scope_records = [
    for scope_file in local.available_scope_files : {
      file = scope_file
      name = try(jsondecode(file("${path.root}/jsons/scopes/${scope_file}")).name, null)
      vct  = try(jsondecode(file("${path.root}/jsons/scopes/${scope_file}")).attributes["vc.verifiable_credential_type"], null)
    }
  ]
  selected_scope_records = length(var.enabled_scope_names) == 0 ? local.available_scope_records : [
    for record in local.available_scope_records : record
    if record.name != null && contains(var.enabled_scope_names, record.name)
  ]
  configured_scope_files = sort(distinct(compact([for record in local.selected_scope_records : record.file])))
  configured_scope_names = sort(distinct(compact([for record in local.selected_scope_records : record.name])))
  configured_scope_vcts  = sort(distinct(compact([for record in local.selected_scope_records : record.vct])))
  unconfigured_scope_names = length(var.enabled_scope_names) == 0 ? [] : sort(distinct(compact([
    for record in local.available_scope_records : record.name
    if record.name != null && !contains(local.configured_scope_names, record.name)
  ])))

  local_mdoc_profiles = var.enable_local_mdoc_test ? jsonencode([
    {
      id         = "local-mdoc-login"
      displayCta = { en = "Sign in with local PID mDoc" }
      credentials = [{
        id              = "identity-mdoc"
        format          = "mso_mdoc"
        credentialTypes = [var.local_mdoc_doctype]
        role            = "primary"
        identitySource  = "credential"
        subjectClaim    = "${var.local_mdoc_namespace}/personal_administrative_number"
        claims = [
          "${var.local_mdoc_namespace}/personal_administrative_number",
          "${var.local_mdoc_namespace}/given_name",
          "${var.local_mdoc_namespace}/family_name",
          "${var.local_mdoc_namespace}/issuing_authority"
        ]
        trust = [{
          type                        = "eudi_pid_trust_list"
          trustListUrl                = var.local_mdoc_trust_list_url
          trustListSigningCertificate = filebase64(var.local_mdoc_trust_list_signing_certificate_path)
          serviceType                 = "http://uri.etsi.org/19602/SvcType/PID/Issuance"
          issuer                      = var.local_pid_provider_identifier
        }]
      }]
    },
    {
      id         = "local-sdjwt-login"
      displayCta = { en = "Sign in with local SD-JWT" }
      credentials = [{
        id              = "identity-sdjwt"
        format          = "dc+sd-jwt"
        credentialTypes = [var.local_sdjwt_vct]
        role            = "primary"
        identitySource  = "credential"
        subjectClaim    = "sub"
        claims          = ["sub", "given_name", "family_name"]
        trust           = [{ type = "self" }]
      }]
    }
  ]) : ""

}

module "realm" {
  source = "./modules/realm"
  providers = {
    keycloak = keycloak
  }

  realm                           = var.realm
  pre_authorized_code_lifespanS   = var.pre_authorized_code_lifespanS
  status_list_server_url          = var.status_list_server_url
  admin_password                  = urlencode(var.admin_password)
  keycloak_url                    = var.keycloak_url
  status_list_enabled             = var.status_list_enabled
  oid4vci_display                 = var.oid4vci_display
  sdjwt_vct                       = join(",", local.configured_scope_vcts)
  sdjwt_enforce_nbf_claim         = var.sdjwt_enforce_nbf_claim
  sdjwt_enforce_exp_claim         = var.sdjwt_enforce_exp_claim
  sdjwt_kb_jwt_max_age            = var.sdjwt_kb_jwt_max_age
  sdjwt_enforce_revocation_status = var.sdjwt_enforce_revocation_status
  sdjwt_response_mode             = var.sdjwt_response_mode
  sdjwt_custom_url_scheme         = var.sdjwt_custom_url_scheme
  sdjwt_access_certificate        = var.sdjwt_access_certificate
  sdjwt_registration_certificate  = var.sdjwt_registration_certificate
  oid4vp_profiles                 = local.local_mdoc_profiles
}

module "users" {
  source = "./modules/users"
  providers = {
    keycloak = keycloak
  }
  realm_id                          = module.realm.realm_id
  realm_name                        = var.realm
  initial_password                  = var.initial_password
  admin_password                    = urlencode(var.admin_password)
  keycloak_url                      = var.keycloak_url
  assign_credential_offer_role      = !var.enable_local_mdoc_test
  verifiable_credential_scope_names = var.enable_local_mdoc_test && contains(local.configured_scope_names, "PIDCredential") ? ["PIDCredential"] : []
  client_scopes_dependency          = module.client_scopes.client_scopes_applied_trigger

  depends_on = [module.client_scopes]
}

module "client_scopes" {
  source = "./modules/client_scopes"
  providers = {
    keycloak = keycloak
  }

  realm_id                  = module.realm.realm_id
  realm_name                = var.realm
  admin_password            = urlencode(var.admin_password)
  keycloak_url              = var.keycloak_url
  scope_files               = local.configured_scope_files
  prune_unconfigured_scopes = local.unconfigured_scope_names
}

module "clients" {
  source = "./modules/clients"
  providers = {
    keycloak = keycloak
  }

  realm_id                         = module.realm.realm_id
  realm_name                       = var.realm
  admin_password                   = urlencode(var.admin_password)
  keycloak_url                     = var.keycloak_url
  clients                          = local.clients
  optional_client_scopes           = local.configured_scope_names
  optional_client_scope_client_ids = var.optional_client_scope_client_ids
  client_scopes_dependency         = module.client_scopes.client_scopes_applied_trigger
  depends_on                       = [module.realm, module.client_scopes]
}

module "keys" {
  source = "./modules/keys"
  providers = {
    keycloak = keycloak
  }

  realm_id                 = module.realm.realm_id
  realm_name               = var.realm
  admin_password           = urlencode(var.admin_password)
  keycloak_url             = var.keycloak_url
  enable_rsa_keys          = var.enable_rsa_keys
  issuer_keystore_path     = var.oid4vc_issuer_keystore_path
  issuer_keystore_type     = var.oid4vc_issuer_keystore_type
  issuer_keystore_password = var.oid4vc_issuer_keystore_password
  issuer_key_alias         = var.oid4vc_issuer_key_alias
}

module "saml_idp" {
  source = "./modules/saml_idp"
  providers = {
    keycloak = keycloak
  }

  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = urlencode(var.admin_password)
  keycloak_url   = var.keycloak_url

  depends_on = [module.realm]
}
