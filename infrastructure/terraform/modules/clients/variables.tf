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
  default = {}
}

variable "client_scopes_dependency" {
  description = "A dependency map from the client_scopes module to ensure proper ordering."
  type        = any
  default     = {}
}

variable "optional_client_scopes" {
  description = "List of optional client scope names to assign to each client"
  type        = list(string)
}

variable "optional_client_scope_client_ids" {
  description = "Client IDs that should receive optional client scopes. If empty, scopes are assigned to all configured clients."
  type        = list(string)
  default     = []
}
