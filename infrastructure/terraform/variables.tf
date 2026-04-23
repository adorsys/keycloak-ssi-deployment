variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  default     = "https://localhost:8443"
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "realm" {
  description = "Keycloak realm"
  type        = string
  default     = "oid4vc-vci"
}

variable "enabled_scope_names" {
  description = "Optional allowlist of OID4VC client scope names to apply. Empty list means all scopes in jsons/scopes."
  type        = list(string)
  default     = []
}

variable "oid4vc_demo_public_valid_redirect_uris" {
  description = "Valid redirect URIs for the oid4vc-demo-public client."
  type        = list(string)
  default = [
    "http://localhost:4200/*",
    "https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
  ]
}

variable "oid4vc_demo_public_web_origins" {
  description = "Web origins for the oid4vc-demo-public client."
  type        = list(string)
  default = [
    "http://localhost:4200",
    "https://adorsys-gis.github.io"
  ]
}

variable "oid4vc_demo_public_post_logout_redirect_uris" {
  description = "Post logout redirect URIs string for oid4vc-demo-public (Keycloak format uses ## as separator)."
  type        = string
  default     = "http://localhost:4200##http://localhost:4200/*##https://adorsys-gis.github.io/keycloak-oid4vc-mock-fe/*"
}

variable "pre_authorized_code_lifespanS" {
  description = "Pre-authorized code lifespan in seconds"
  type        = string
  default     = "120"
}

variable "status_list_server_url" {
  description = "URL of the status list server"
  type        = string
  default     = "https://statuslist.eudi-adorsys.com"
}

variable "openid4vc_rest_api_client_secret" {
  description = "Client secret for the openid4vc-rest-api confidential client"
  type        = string
  sensitive   = true
}

variable "openid4vc_rest_api_valid_redirect_uris" {
  description = "Valid redirect URIs for the openid4vc-rest-api client."
  type        = list(string)
  default = [
    "https://localhost:8443/callback",
    "http://back.localhost.com/*"
  ]
}

variable "openid4vc_rest_api_web_origins" {
  description = "Web origins for the openid4vc-rest-api client."
  type        = list(string)
  default = [
    "https://localhost:8443"
  ]
}

variable "openid4vc_rest_api_post_logout_redirect_uris" {
  description = "Post logout redirect URIs string for openid4vc-rest-api (Keycloak format uses ## as separator)."
  type        = string
  default     = "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
}

variable "sdjwt_enforce_nbf_claim" {
  description = "Enforce nbf claim for SD-JWT"
  type        = string
  default     = "false"
}

variable "sdjwt_enforce_exp_claim" {
  description = "Enforce exp claim for SD-JWT"
  type        = string
  default     = "false"
}

variable "sdjwt_kb_jwt_max_age" {
  description = "Max age globally for kb-jwt for SD-JWT"
  type        = string
  default     = "60"
}

variable "sdjwt_enforce_revocation_status" {
  description = "Enforce revocation status for SD-JWT"
  type        = string
  default     = "false"
}

variable "sdjwt_response_mode" {
  description = "Response mode for SdJwtAuthenticator (e.g., direct_post.jwt)"
  type        = string
  default     = "direct_post.jwt"
}

variable "sdjwt_custom_url_scheme" {
  description = "Custom wallet URL scheme for SdJwtAuthenticator"
  type        = string
  default     = "haip-vp://"
}

variable "sdjwt_client_id_scheme" {
  description = "Client ID scheme for SdJwtAuthenticator (e.g., x509_hash)"
  type        = string
  default     = "x509_hash"
}

variable "sdjwt_query_language" {
  description = "Query language for SdJwtAuthenticator (e.g., dcql_query)"
  type        = string
  default     = "dcql_query"
}

variable "sdjwt_access_certificate" {
  description = "Base64 DER access certificate for SdJwtAuthenticator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sdjwt_registration_certificate" {
  description = "Registration certificate JWT for SdJwtAuthenticator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "initial_password" {
  description = "Initial password for user"
  type        = string
  sensitive   = true
}

variable "status_list_enabled" {
  description = "Enable or disable the status list for the realm"
  type        = bool
  default     = false
}

variable "enable_rsa_keys" {
  description = "Enable RSA key import/usage for OID4VC. Set false to disable RSA providers."
  type        = bool
  default     = false
}

variable "oid4vc_keystore_path" {
  description = "Absolute keystore path on the Keycloak host runtime filesystem for OID4VC signing keys (not the Terraform runner path)."
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
  default     = "PKCS12"
}

variable "oid4vc_ecdsa_key_alias" {
  description = "Alias of persistent ES256 key in keystore."
  type        = string
  default     = "ecdsa_key"
}

variable "oid4vci_display" {
  description = "Issuer root display metadata as JSON array string for realm attribute oid4vci.display"
  type        = string
  default     = ""
}

variable "optional_client_scope_client_ids" {
  description = "Client IDs that should receive optional OID4VC client scopes. Empty list applies scopes to all configured clients."
  type        = list(string)
  default     = []
}
