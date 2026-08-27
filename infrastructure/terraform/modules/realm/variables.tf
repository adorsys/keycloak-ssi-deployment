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

variable "sdjwt_credential_types" {
  description = "Comma-separated list of credential types accepted by the OID4VP authenticator (legacy single-credential mode)."
  type        = string
  default     = "https://credentials.example.com/identity_credential"
}

variable "sdjwt_require_nbf_claim" {
  description = "Require Not Before claim for presented credentials."
  type        = string
  default     = "false"
}

variable "sdjwt_require_exp_claim" {
  description = "Require Expiration claim for presented credentials."
  type        = string
  default     = "false"
}

variable "sdjwt_holder_binding_proof_max_age" {
  description = "Maximum age in seconds of accepted holder-binding proofs (KB-JWT)."
  type        = string
  default     = "60"
}

variable "sdjwt_enforce_revocation_status" {
  description = "Reject credentials whose status indicates they are no longer valid (Token Status List)."
  type        = string
  default     = "false"
}

variable "sdjwt_response_mode" {
  description = "How wallets deliver the authorization response: direct_post or direct_post.jwt."
  type        = string
  default     = "direct_post.jwt"
}

variable "sdjwt_client_identifier_prefix" {
  description = "Client identifier prefix for authorization requests: x509_san_dns or x509_hash."
  type        = string
  default     = "x509_hash"
}

variable "sdjwt_request_uri_method" {
  description = "How wallets dereference request_uri: get or post."
  type        = string
  default     = "get"
}

variable "sdjwt_custom_url_scheme" {
  description = "Custom wallet URL scheme for authorization request links (e.g. openid4vp:// or haip-vp://)."
  type        = string
  default     = "openid4vp://"
}

variable "sdjwt_access_certificate" {
  description = "Base64 DER X.509 certificate for request object x5c header."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sdjwt_registration_certificate" {
  description = "Registration certificate JWT advertised via verifier_info."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sdjwt_require_cryptographic_holder_binding" {
  description = "When false, DCQL query requests presentation without KB-JWT."
  type        = string
  default     = "true"
}

variable "sdjwt_verify_issuer_claim" {
  description = "Require the iss claim to match this realm's issuer URL."
  type        = string
  default     = "true"
}

variable "sdjwt_fallback_to_iso_spec_session_transcript" {
  description = "Allow fallback to ISO-spec session transcript for mDoc when OpenID4VP-spec algorithm fails."
  type        = string
  default     = "false"
}

variable "sdjwt_profiles" {
  description = "Optional JSON array of authentication profiles. Leave empty for legacy single-credential mode."
  type        = string
  default     = ""
}

variable "sdjwt_transaction_data" {
  description = "Optional comma-separated base64url-encoded transaction_data JSON objects (OpenID4VP 5.1)."
  type        = string
  default     = ""
}

variable "sdjwt_verifier_info" {
  description = "Optional JSON array of verifier_info objects merged with the registration certificate entry."
  type        = string
  default     = ""
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
