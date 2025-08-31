terraform {
    required_providers {
        keycloak = {
            source  = "keycloak/keycloak"
            version = "5.3.0"
        }
    }
}

module "stage" {
    source = "../modules/keycloak"

    keycloak_url         = var.keycloak_url
    admin_password       = var.admin_password
}
