terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

resource "keycloak_user" "francis" {
  realm_id   = var.realm_id
  username   = var.username
  first_name = var.first_name
  last_name  = var.last_name
  email      = var.email
  enabled    = true
  initial_password {
    value     = var.initial_password
    temporary = false
  }
}

resource "keycloak_user" "max_mustermann" {
  realm_id   = var.realm_id
  username   = var.max_mustermann_username
  first_name = var.max_mustermann_first_name
  last_name  = var.max_mustermann_last_name
  email      = var.max_mustermann_email
  enabled    = true

  initial_password {
    value     = var.max_mustermann_initial_password
    temporary = false
  }
}
