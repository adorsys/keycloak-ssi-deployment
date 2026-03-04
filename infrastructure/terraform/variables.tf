variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "https://localhost:8443"
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  default     = "admin"
}

variable "realm" {
  description = "Keycloak realm"
  type        = string
  default     = "oid4vc-vci"
}

variable "clients" {
  description = "A map of client configurations."
  type = map(object({
    name                         = string
    client_secret                = optional(string)
    enabled                      = bool
    access_type                  = string
    standard_flow_enabled        = bool
    direct_access_grants_enabled = bool
    valid_redirect_uris          = list(string)
    web_origins                  = list(string)
    full_scope_allowed           = bool
    attributes                   = map(string)
  }))
  default = {
    "oid4vc-demo-public" = {
      name                         = "oid4vc-demo-public"
      enabled                      = true
      access_type                  = "PUBLIC"
      standard_flow_enabled        = true
      direct_access_grants_enabled = false
      valid_redirect_uris          = ["http://localhost:4200/*"]
      web_origins                  = ["http://localhost:4200"]
      full_scope_allowed           = true
      attributes = {
        "oid4vci.enabled"           = "true"
        "post.logout.redirect.uris" = "http://localhost:4200##http://localhost:4200/*"
      }
    },
    "openid4vc-rest-api" = {
      name                         = "openid4vc-rest-api"
      client_secret                = "uArydomqOymeF0tBrtipkPYujNNUuDlt"
      enabled                      = true
      access_type                  = "CONFIDENTIAL"
      standard_flow_enabled        = true
      direct_access_grants_enabled = true
      full_scope_allowed           = true
      valid_redirect_uris = [
        "https://localhost:8443/callback",
        "https://issuer.eudi-adorsys.com/services/*",
        "http://back.localhost.com/*"
      ]
      web_origins = [
        "https://issuer.eudi-adorsys.com/services",
        "https://localhost:8443"
      ]
      attributes = {
        "oid4vci.enabled"             = "true"
        "client.secret.creation.time" = "1719785014"
        "post.logout.redirect.uris"   = "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
      }
    }
  }
}

variable "optional_client_scopes" {
  description = "List of optional client scope names to assign to clients"
  type        = list(string)
  default     = ["IdentityCredential", "KMACredential", "SteuerberaterCredential"]
}

variable "pre_authorized_code_lifespanS" {
  description = "Pre-authorized code lifespan in seconds"
  type        = string
  default     = "120"
}

variable "status_list_server_url" {
  description = "URL of the status list server"
  type        = string
  default     = "https://statuslist.eudi-adorsys.com"
}

variable "sdjwt_vct" {
  description = "Comma-separated list of VCT entries for sd-jwt authenticator"
  type        = string
  default     = "stbk_westfalen_lippe,https://credentials.example.com/identity_credential,person_vct"
}

variable "sdjwt_enforce_nbf_claim" {
  description = "Enforce nbf claim for SD-JWT"
  type        = string
  default     = "false"
}

variable "sdjwt_enforce_exp_claim" {
  description = "Enforce exp claim for SD-JWT"
  type        = string
  default     = "false"
}

variable "sdjwt_kb_jwt_max_age" {
  description = "Max age globally for kb-jwt for SD-JWT"
  type        = string
  default     = "60"
}

variable "sdjwt_enforce_revocation_status" {
  description = "Enforce revocation status for SD-JWT"
  type        = string
  default     = "false"
}

variable "initial_password" {
  description = "Initial password for user"
  type        = string
  default     = "francis"
}

variable "status_list_enabled" {
  description = "Enable or disable the status list for the realm"
  type        = bool
  default     = false
}
