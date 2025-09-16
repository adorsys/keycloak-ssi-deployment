variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "https://localhost:8443"
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

variable "pre_authorized_code_lifespanS" {
  description = "Pre-authorized code lifespan in seconds"
  type        = string
  default     = "120"
}

variable "status_list_server_url" {
  description = "URL of the status list server"
  type        = string
  default     = "https://statuslist.eudi-adorsys.com/"
}
