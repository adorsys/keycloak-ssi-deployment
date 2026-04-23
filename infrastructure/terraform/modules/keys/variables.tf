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

variable "oid4vc_keystore_path" {
  description = "Absolute keystore path visible to Keycloak runtime for OID4VC signing keys."
  type        = string
}

variable "oid4vc_keystore_password" {
  description = "Password for OID4VC keystore."
  type        = string
  sensitive   = true
}

variable "oid4vc_keystore_type" {
  description = "Keystore type for OID4VC key provider."
  type        = string
}

variable "oid4vc_ecdsa_key_alias" {
  description = "Alias of persistent ES256 key in keystore."
  type        = string
}
