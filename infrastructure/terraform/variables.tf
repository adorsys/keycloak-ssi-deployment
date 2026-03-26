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

variable "optional_client_scopes" {
  description = "List of optional client scope names to assign to clients"
  type        = list(string)
  default     = ["IdentityCredential", "AdorsysCompanyCredential", "BankEmployeeCredential", "CityRegistryCredential"]
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

variable "sdjwt_vct" {
  description = "Optional override for sd-jwt authenticator VCT list. Leave empty to auto-derive from configured credential scopes."
  type        = string
  default     = ""
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
