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

# Lookup the OpenID4VCI credential-offer-create realm role (required for credential offer creation)
data "keycloak_role" "credential_offer_create" {
  realm_id = var.realm_id
  name     = "credential-offer-create"
}

# Assign the credential-offer-create realm role to the user
resource "keycloak_user_roles" "francis_realm_roles" {
  realm_id = var.realm_id
  user_id  = keycloak_user.francis.id

  role_ids = [
    data.keycloak_role.credential_offer_create.id,
  ]
}
