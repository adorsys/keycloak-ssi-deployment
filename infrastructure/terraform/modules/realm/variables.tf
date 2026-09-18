variable "realm" {
  description = "Keycloak realm name"
  type        = string
}

variable "realm_frontend_url" {
  description = "Optional public HTTPS origin advertised by the realm"
  type        = string
  default     = ""
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

variable "sdjwt_response_mode" {
  description = "Response mode for SdJwtAuthenticator"
  type        = string
}

variable "oid4vp_client_identifier_prefix" {
  description = "OpenID4VP verifier client identifier prefix"
  type        = string
}

variable "sdjwt_custom_url_scheme" {
  description = "Custom wallet URL scheme for SdJwtAuthenticator"
  type        = string
}

variable "sdjwt_access_certificate" {
  description = "Base64 DER access certificate for SdJwtAuthenticator"
  type        = string
  sensitive   = true
}

variable "sdjwt_registration_certificate" {
  description = "Registration certificate JWT for SdJwtAuthenticator"
  type        = string
  sensitive   = true
}

variable "oid4vp_profiles" {
  description = "JSON authentication profiles for the oid4vp-authenticator"
  type        = string
  default     = ""
}

variable "oid4vp_import_unknown_users" {
  description = "Create unknown users after successful origin and credential verification"
  type        = bool
  default     = false
}

variable "oid4vp_import_idp_alias" {
  description = "Alias of the hidden identity provider that owns imports, mappers, and federated links"
  type        = string
  default     = "oid4vp-import"
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

variable "oid4vci_display" {
  description = "Issuer root display metadata as JSON array string for realm attribute oid4vci.display"
  type        = string
  default     = ""
}
