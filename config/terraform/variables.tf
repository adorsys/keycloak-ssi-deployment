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

variable "keystore_password" {
  description = "Password for Keycloak keystore"
  type        = string
  default     = "store_key_password"
}

variable "keystore_path" {
  description = "Path to Keycloak keystore file"
  type        = string
  default     = "../../kc_keystore.pkcs12"
}
