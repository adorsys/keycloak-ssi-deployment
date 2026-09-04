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

variable "prune_unconfigured_scopes" {
  description = "List of client scope names to delete from Keycloak if present"
  type        = list(string)
  default     = []
}
