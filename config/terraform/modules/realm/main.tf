terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.3.0"
    }
  }
}

resource "keycloak_realm" "oid4vc_vci" {
  realm   = var.realm
  enabled = true
  attributes = {
    preAuthorizedCodeLifespanS = var.pre_authorized_code_lifespanS
  }
}
