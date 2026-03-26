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

data "keycloak_role" "default_realm_role" {
  realm_id = var.realm_id
  name     = "default-roles-${var.realm_name}"
}

# Assign the credential-offer-create realm role to the user
resource "keycloak_user_roles" "francis_realm_roles" {
  realm_id = var.realm_id
  user_id  = keycloak_user.francis.id
  # Keep default/composite realm roles intact; only ensure this role is present.
  exhaustive = false

  role_ids = [
    data.keycloak_role.default_realm_role.id,
    data.keycloak_role.credential_offer_create.id,
  ]
}
