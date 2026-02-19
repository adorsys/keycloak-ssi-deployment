# Data source to check if Keycloak is accessible and ready
# This ensures Keycloak is running before proceeding with any operations
data "keycloak_realm" "master" {
  realm = "master"
}

# Create the OID4VC realm with all necessary configurations
module "realm" {
  source = "./modules/realm"
  providers = {
    keycloak = keycloak
  }

  realm                         = var.realm
  login_theme                   = var.login_theme
  pre_authorized_code_lifespanS = var.pre_authorized_code_lifespanS
  status_list_server_url        = var.status_list_server_url
  admin_password                = urlencode(var.admin_password)
  keycloak_url                  = var.keycloak_url
  sdjwt_vct                     = var.sdjwt_vct

  # Ensure Keycloak is accessible before creating realm
  depends_on = [data.keycloak_realm.master]
}

# Create test users after realm is ready
module "users" {
  source = "./modules/users"
  providers = {
    keycloak = keycloak
  }

  realm_id         = module.realm.realm_id
  initial_password = var.initial_password

  # Wait for realm to be fully configured (including verifiable credentials enabled)
  depends_on = [module.realm]
}

# Configure client scopes after realm is ready
module "client_scopes" {
  source = "./modules/client_scopes"
  providers = {
    keycloak = keycloak
  }

  realm_id          = module.realm.realm_id
  realm_name        = var.realm
  admin_password    = urlencode(var.admin_password)
  keycloak_url      = var.keycloak_url
  status_list_enabled = var.status_list_enabled

  depends_on = [module.realm]
}

# Configure clients after realm and client scopes are ready
module "clients" {
  source = "./modules/clients"
  providers = {
    keycloak = keycloak
  }

  realm_id                 = module.realm.realm_id
  realm_name               = var.realm
  admin_password           = urlencode(var.admin_password)
  keycloak_url             = var.keycloak_url
  sdjwt_vct                = var.sdjwt_vct
  clients                  = var.clients
  optional_client_scopes   = var.optional_client_scopes
  client_scopes_dependency = module.client_scopes.client_scopes_applied_trigger

  # Ensure proper order: realm -> client_scopes -> clients
  depends_on = [module.realm, module.client_scopes]
}

# Import cryptographic keys after realm is ready
module "keys" {
  source = "./modules/keys"
  providers = {
    keycloak = keycloak
  }

  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = urlencode(var.admin_password)
  keycloak_url   = var.keycloak_url

  # Wait for realm to be ready
  depends_on = [module.realm]
}

# Configure SAML identity provider after realm is ready
module "saml_idp" {
  source = "./modules/saml_idp"
  providers = {
    keycloak = keycloak
  }

  realm_id       = module.realm.realm_id
  realm_name     = var.realm
  admin_password = urlencode(var.admin_password)
  keycloak_url   = var.keycloak_url

  # Wait for realm to be ready
  depends_on = [module.realm]
}
