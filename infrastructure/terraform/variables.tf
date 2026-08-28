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
  description = "OID4VC client scopes to apply and grant to the managed demo users. Empty means all scopes in jsons/scopes."
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

variable "oid4vp_authentication_profiles" {
  description = "Optional JSON array of OID4VP authentication profiles. Empty uses the legacy single-credential configuration."
  type        = string
  default     = ""
}

variable "oid4vp_require_nbf_claim" {
  description = "Require the nbf time claim in presented SD-JWT credentials."
  type        = string
  default     = "false"
}

variable "oid4vp_require_exp_claim" {
  description = "Require the exp time claim in presented SD-JWT credentials."
  type        = string
  default     = "false"
}

variable "oid4vp_holder_binding_proof_max_age" {
  description = "Maximum accepted age in seconds for holder-binding proofs."
  type        = string
  default     = "60"
}

variable "oid4vp_enforce_revocation_status" {
  description = "Reject credentials marked invalid by the Token Status List mechanism."
  type        = string
  default     = "false"
}

variable "oid4vp_response_mode" {
  description = "Response mode for the OID4VP authenticator (e.g., direct_post.jwt)"
  type        = string
  default     = "direct_post.jwt"
}

variable "oid4vp_request_uri_method" {
  description = "HTTP method wallets use to dereference request_uri."
  type        = string
  default     = "get"
}

variable "oid4vp_custom_url_scheme" {
  description = "Custom wallet URL scheme for authorization request links"
  type        = string
  default     = "haip-vp://"
}

variable "oid4vp_client_identifier_prefix" {
  description = "Client identifier prefix for the OID4VP authenticator (e.g., x509_hash)"
  type        = string
  default     = "x509_hash"
}

variable "oid4vp_access_certificate" {
  description = "Base64 DER access certificate for the OID4VP authenticator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oid4vp_registration_certificate" {
  description = "Registration certificate JWT for the OID4VP authenticator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oid4vp_transaction_data" {
  description = "Optional comma-separated or newline-separated base64url-encoded transaction_data objects."
  type        = string
  sensitive   = true
  default     = ""
}

variable "oid4vp_verifier_info" {
  description = "Optional JSON array of verifier_info objects."
  type        = string
  sensitive   = true
  default     = ""
}

variable "oid4vp_require_cryptographic_holder_binding" {
  description = "Require cryptographic holder binding for presented credentials."
  type        = string
  default     = "true"
}

variable "oid4vp_verify_issuer_claim" {
  description = "Require the SD-JWT iss claim to match the realm issuer URL."
  type        = string
  default     = "true"
}

variable "oid4vp_fallback_to_iso_spec_session_transcript" {
  description = "Allow an ISO-spec session transcript fallback when OpenID4VP mDoc verification fails."
  type        = string
  default     = "false"
}

variable "initial_password" {
  description = "Initial password for user"
  type        = string
  sensitive   = true
}

variable "max_mustermann_initial_password" {
  description = "Initial password of the payslip demo user"
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
