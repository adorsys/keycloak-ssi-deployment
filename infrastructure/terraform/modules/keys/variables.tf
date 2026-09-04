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
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "enable_rsa_keys" {
  description = "Enable RSA key import/usage for OID4VC"
  type        = bool
  default     = false
}

variable "issuer_keystore_path" {
  type    = string
  default = ""
}

variable "issuer_keystore_type" {
  type    = string
  default = "PKCS12"
}

variable "issuer_keystore_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "issuer_key_alias" {
  type    = string
  default = "ecdsa_key"
}
