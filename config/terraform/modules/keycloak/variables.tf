variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
}

variable "realm" {
  description = "Keycloak realm"
  type        = string
  default     = "oid4vc-vci"
}