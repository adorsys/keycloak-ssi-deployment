terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.3.0"
    }
  }
}

provider "keycloak" {
  client_id                = "admin-cli"
  username                 = "admin"
  password                 = var.admin_password
  url                      = var.keycloak_url
  realm                    = "master"
  tls_insecure_skip_verify = true
}
