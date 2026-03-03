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
  sdjwt_vct                       = var.sdjwt_vct
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
  clients                  = var.clients
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
