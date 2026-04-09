variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "https://localhost:8443"
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "realm" {
  description = "Keycloak realm"
  type        = string
  default     = "oid4vc-vci"
}

variable "oid4vc_demo_public_valid_redirect_uris" {
  description = "Valid redirect URIs for the oid4vc-demo-public client."
  type        = list(string)
  default = [
    "http://localhost:4200/*",
    "https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
  ]
}

variable "oid4vc_demo_public_web_origins" {
  description = "Web origins for the oid4vc-demo-public client."
  type        = list(string)
  default = [
    "http://localhost:4200",
    "https://adorsys-gis.github.io"
  ]
}

variable "oid4vc_demo_public_post_logout_redirect_uris" {
  description = "Post logout redirect URIs string for oid4vc-demo-public (Keycloak format uses ## as separator)."
  type        = string
  default     = "http://localhost:4200##http://localhost:4200/*##https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
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

variable "openid4vc_rest_api_client_secret" {
  description = "Client secret for the openid4vc-rest-api confidential client"
  type        = string
  sensitive   = true
}

variable "openid4vc_rest_api_valid_redirect_uris" {
  description = "Valid redirect URIs for the openid4vc-rest-api client."
  type        = list(string)
  default = [
    "https://localhost:8443/callback",
    "http://back.localhost.com/*"
  ]
}

variable "openid4vc_rest_api_web_origins" {
  description = "Web origins for the openid4vc-rest-api client."
  type        = list(string)
  default = [
    "https://localhost:8443"
  ]
}

variable "openid4vc_rest_api_post_logout_redirect_uris" {
  description = "Post logout redirect URIs string for openid4vc-rest-api (Keycloak format uses ## as separator)."
  type        = string
  default     = "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
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
  sensitive   = true
}

variable "status_list_enabled" {
  description = "Enable or disable the status list for the realm"
  type        = bool
  default     = false
}

variable "enable_rsa_keys" {
  description = "Enable RSA key import/usage for OID4VC. Set false to disable RSA providers."
  type        = bool
  default     = false
}

variable "oid4vci_display" {
  description = "Issuer root display metadata as JSON array string for realm attribute oid4vci.display"
  type        = string
  default     = ""
}
