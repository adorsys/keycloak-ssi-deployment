variable "realm" {
  description = "Keycloak realm name"
  type        = string
}

variable "pre_authorized_code_lifespanS" {
  description = "Pre-authorized code lifespan in seconds"
  type        = string
}

variable "status_list_server_url" {
  description = "URL of the status list server"
  type        = string
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "oid4vp_authentication_profiles" {
  description = "Optional JSON array of OID4VP authentication profiles. Empty uses the legacy single-credential configuration."
  type        = string
}

variable "oid4vp_credential_types" {
  description = "Comma-separated list of credential types accepted by the OID4VP authenticator"
  type        = string
}

variable "oid4vp_require_nbf_claim" {
  description = "Require the nbf time claim in presented SD-JWT credentials"
  type        = string
}

variable "oid4vp_require_exp_claim" {
  description = "Require the exp time claim in presented SD-JWT credentials"
  type        = string
}

variable "oid4vp_holder_binding_proof_max_age" {
  description = "Maximum accepted age in seconds for holder-binding proofs"
  type        = string
}

variable "oid4vp_enforce_revocation_status" {
  description = "Reject credentials marked invalid by the Token Status List mechanism"
  type        = string
}

variable "oid4vp_response_mode" {
  description = "Response mode for the OID4VP authenticator"
  type        = string
}

variable "oid4vp_request_uri_method" {
  description = "HTTP method wallets use to dereference request_uri"
  type        = string
}

variable "oid4vp_custom_url_scheme" {
  description = "Custom wallet URL scheme for authorization request links"
  type        = string
}

variable "oid4vp_client_identifier_prefix" {
  description = "Client identifier prefix for the OID4VP authenticator"
  type        = string
}

variable "oid4vp_access_certificate" {
  description = "Base64 DER access certificate for the OID4VP authenticator"
  type        = string
  sensitive   = true
}

variable "oid4vp_registration_certificate" {
  description = "Registration certificate JWT for the OID4VP authenticator"
  type        = string
  sensitive   = true
}

variable "oid4vp_transaction_data" {
  description = "Optional comma-separated or newline-separated base64url-encoded transaction_data objects"
  type        = string
  sensitive   = true
}

variable "oid4vp_verifier_info" {
  description = "Optional JSON array of verifier_info objects"
  type        = string
  sensitive   = true
}

variable "oid4vp_require_cryptographic_holder_binding" {
  description = "Require cryptographic holder binding for presented credentials"
  type        = string
}

variable "oid4vp_verify_issuer_claim" {
  description = "Require the SD-JWT iss claim to match the realm issuer URL"
  type        = string
}

variable "oid4vp_fallback_to_iso_spec_session_transcript" {
  description = "Allow an ISO-spec session transcript fallback when OpenID4VP mDoc verification fails"
  type        = string
}

variable "login_theme" {
  description = "Login theme for the realm (set to keycloak.v2+oid4vp for OID4VP support)"
  type        = string
  default     = "keycloak.v2+oid4vp"
}

variable "status_list_enabled" {
  description = "Enable or disable the status list for the realm"
  type        = bool
}

variable "oid4vci_display" {
  description = "Issuer root display metadata as JSON array string for realm attribute oid4vci.display"
  type        = string
  default     = ""
}
