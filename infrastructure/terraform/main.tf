locals {
  # Non-secret parts of client configuration live in code; the confidential client secret is injected at runtime.
  clients = {
    "oid4vc-demo-public" = {
      name                         = "oid4vc-demo-public"
      enabled                      = true
      access_type                  = "PUBLIC"
      standard_flow_enabled        = true
      direct_access_grants_enabled = false
      valid_redirect_uris = [
        "http://localhost:4200/*",
        "https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
      ]
      web_origins = [
        "http://localhost:4200",
        "https://adorsys-gis.github.io"
      ]
      full_scope_allowed = true
      attributes = {
        "oid4vci.enabled"           = "true"
        "post.logout.redirect.uris" = "http://localhost:4200##http://localhost:4200/*##https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
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
      valid_redirect_uris = [
        "https://localhost:8443/callback",
        "https://issuer.eudi-adorsys.com/services/*",
        "http://back.localhost.com/*"
      ]
      web_origins = [
        "https://issuer.eudi-adorsys.com/services",
        "https://localhost:8443"
      ]
      attributes = {
        "oid4vci.enabled"             = "true"
        "client.secret.creation.time" = "1719785014"
        "post.logout.redirect.uris"   = "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
      }
    }
  }

  # Keep authenticator VCTs aligned with all configured OID4VC client scopes.
  configured_scope_files = fileset("${path.root}/jsons/scopes", "*.json")
  configured_scope_vcts = sort(distinct(compact([
    for scope_file in local.configured_scope_files :
    try(jsondecode(file("${path.root}/jsons/scopes/${scope_file}")).attributes["vc.verifiable_credential_type"], null)
  ])))
  sdjwt_vct_effective = trimspace(var.sdjwt_vct) != "" ? trimspace(var.sdjwt_vct) : join(",", local.configured_scope_vcts)
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
  sdjwt_vct                       = local.sdjwt_vct_effective
  sdjwt_enforce_nbf_claim         = var.sdjwt_enforce_nbf_claim
  sdjwt_enforce_exp_claim         = var.sdjwt_enforce_exp_claim
  sdjwt_kb_jwt_max_age            = var.sdjwt_kb_jwt_max_age
  sdjwt_enforce_revocation_status = var.sdjwt_enforce_revocation_status
}

module "users" {
  source = "./modules/users"
  providers = {
    keycloak = keycloak
  }
  realm_id         = module.realm.realm_id
  realm_name       = var.realm
  initial_password = var.initial_password
}

module "client_scopes" {
  source = "./modules/client_scopes"
  providers = {
    keycloak = keycloak
  }

  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = urlencode(var.admin_password)
  keycloak_url   = var.keycloak_url
}

module "clients" {
  source = "./modules/clients"
  providers = {
    keycloak = keycloak
  }

  realm_id                 = module.realm.realm_id
  realm_name               = var.realm
  admin_password           = urlencode(var.admin_password)
  keycloak_url             = var.keycloak_url
  clients                  = local.clients
  optional_client_scopes   = var.optional_client_scopes
  client_scopes_dependency = module.client_scopes.client_scopes_applied_trigger
  depends_on               = [module.realm, module.client_scopes]
}

module "keys" {
  source = "./modules/keys"
  providers = {
    keycloak = keycloak
  }

  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = urlencode(var.admin_password)
  keycloak_url   = var.keycloak_url
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
