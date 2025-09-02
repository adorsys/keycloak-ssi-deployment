variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "http://localhost:8080"
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  default     = "admin"
}

variable "realm" {
  description = "Keycloak realm"
  type        = string
  default     = "oid4vc-vci"
}

variable "client_secret" {
  description = "Client secret for openid4vc-rest-api"
  type        = string
  default     = "uArydomqOymeF0tBrtipkPYujNNUuDlt"
}
