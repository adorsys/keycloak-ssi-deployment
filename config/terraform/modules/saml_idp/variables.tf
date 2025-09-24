variable "realm_id" {
  description = "The realm ID this identity provider belongs to"
  type        = string
}

variable "realm_name" {
  description = "The realm name this identity provider belongs to"
  type        = string
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak server URL"
  type        = string
}
