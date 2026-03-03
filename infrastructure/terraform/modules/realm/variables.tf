variable "realm" {
  description = "Keycloak realm name"
  type        = string
}

variable "pre_authorized_code_lifespanS" {
  description = "Pre-authorized code lifespan in seconds"
  type        = string
}

variable "status_list_server_url" {
  description = "URL of the status list server"
  type        = string
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "sdjwt_vct" {
  description = "Comma-separated list of VCT entries for sd-jwt authenticator"
  type        = string
}

variable "sdjwt_enforce_nbf_claim" {
  description = "Enforce nbf claim for SD-JWT"
  type        = string
}

variable "sdjwt_enforce_exp_claim" {
  description = "Enforce exp claim for SD-JWT"
  type        = string
}

variable "sdjwt_kb_jwt_max_age" {
  description = "Max age globally for kb-jwt for SD-JWT"
  type        = string
}

variable "sdjwt_enforce_revocation_status" {
  description = "Enforce revocation status for SD-JWT"
  type        = string
}

variable "login_theme" {
  description = "Login theme for the realm (set to keycloak.v2+oid4vp for OID4VP support)"
  type        = string
  default     = "keycloak.v2+oid4vp"
}

variable "status_list_enabled" {
  description = "Enable or disable the status list for the realm"
  type        = bool
}
