module "realm" {
  source = "./modules/realm"
  providers = {
    keycloak = keycloak
  }
  realm  = var.realm
  pre_authorized_code_lifespanS = "120"
}

module "users" {
  source = "./modules/users"
  providers = {
    keycloak = keycloak
  }
  realm_id = module.realm.realm_id
  initial_password = "0m5OT6yrLP1YngVMuZB1QKXv085qxGOQ5lHFurtlbcY="
}

module "clients" {
  source = "./modules/clients"
  providers = {
    keycloak = keycloak
  }
  realm_id = module.realm.realm_id
  realm_name = var.realm
  admin_password = var.admin_password
  keycloak_url = var.keycloak_url
  client_secret = var.client_secret
}

module "client_scopes" {
  source = "./modules/client_scopes"
  providers = {
    keycloak = keycloak
  }
  realm_id = module.realm.realm_id
  realm_name = var.realm
  admin_password = var.admin_password
  keycloak_url = var.keycloak_url
}

module "keys" {
  source = "./modules/keys"
  providers = {
    keycloak = keycloak
  }
  realm_id = module.realm.realm_id
  realm_name = var.realm
  admin_password = var.admin_password
  keycloak_url = var.keycloak_url
  keystore_password = var.keystore_password
  keystore_path = var.keystore_path
}