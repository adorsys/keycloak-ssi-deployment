variable "realm_id" {
  description = "Keycloak realm ID"
  type        = string
}

variable "username" {
  description = "User name"
  type        = string
  default     = "francis"
}

variable "first_name" {
  description = "User first name"
  type        = string
  default     = "Francis"
}

variable "last_name" {
  description = "User last name"
  type        = string
  default     = "Pouatcha"
}

variable "email" {
  description = "User email"
  type        = string
  default     = "fpo@mail.de"
}

variable "initial_password" {
  description = "Initial password for user"
  type        = string
}

variable "assign_credential_offer_role" {
  description = "Assign the optional credential-offer-create realm role when that Keycloak feature exposes it"
  type        = bool
  default     = true
}

variable "realm_name" {
  description = "Realm containing the user"
  type        = string
  default     = "oid4vc-vci"
}

variable "admin_password" {
  description = "URL-encoded Keycloak bootstrap administrator password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "https://localhost:8443"
}

variable "verifiable_credential_scope_names" {
  description = "Credential scopes to grant to the provisioned user"
  type        = list(string)
  default     = []
}

variable "client_scopes_dependency" {
  description = "Client-scope provisioning trigger used to order user credential grants"
  type        = any
  default     = {}
}
