variable "realm_id" {
  description = "Keycloak realm ID"
  type        = string
}

variable "realm_name" {
  description = "Keycloak realm name"
  type        = string
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "scope_files" {
  description = "List of client scope JSON filenames (from jsons/scopes) to apply."
  type        = list(string)
  default     = []
}

variable "pdi_enabled" {
  description = "Whether to gate the configured credential scope on presentation during issuance"
  type        = bool
  default     = true
}

variable "pdi_scope_name" {
  description = "Name of the credential scope to gate when presentation during issuance is enabled"
  type        = string
  default     = "DatevCompanyCredential"
}

variable "pdi_profile_id" {
  description = "OID4VP profile ID to reference from the gated credential scope"
  type        = string
  default     = "datev-pid-presentation"
}
