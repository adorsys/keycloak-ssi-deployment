module "realm" {
  source = "./modules/realm"
  providers = {
    keycloak = keycloak
  }
  realm                         = var.realm
  pre_authorized_code_lifespanS = var.pre_authorized_code_lifespanS
  status_list_server_url        = var.status_list_server_url
}

module "users" {
  source = "./modules/users"
  providers = {
    keycloak = keycloak
  }
  realm_id         = module.realm.realm_id
  initial_password = "francis"
}

module "client_scopes" {
  source = "./modules/client_scopes"
  providers = {
    keycloak = keycloak
  }
  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = var.admin_password
  keycloak_url   = var.keycloak_url
}

module "clients" {
  source = "./modules/clients"
  providers = {
    keycloak = keycloak
  }
  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = var.admin_password
  keycloak_url   = var.keycloak_url
  client_secret  = var.client_secret

  depends_on = [module.realm, module.client_scopes]
}

module "keys" {
  source = "./modules/keys"
  providers = {
    keycloak = keycloak
  }
  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = var.admin_password
  keycloak_url   = var.keycloak_url
}
