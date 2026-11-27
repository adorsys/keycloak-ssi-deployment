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
  description = "Gate the selected credential scope on a successful presentation-during-issuance flow."
  type        = bool
  default     = false
}

variable "pdi_scope_name" {
  description = "Credential scope name to gate when presentation during issuance is enabled."
  type        = string
  default     = "IdentityCredential"
}

variable "pdi_profile_id" {
  description = "OID4VP profile used by the selected gated credential scope."
  type        = string
  default     = "identity-pid-presentation"
}
