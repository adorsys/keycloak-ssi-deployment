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
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "client_secret" {
  description = "Client secret for openid4vc-rest-api"
  type        = string
}

variable "test_client_url" {
  description = "Base URL for test-client"
  type        = string
}

variable "sdjwt_vct" {
  description = "Comma-separated list of VCT entries for sd-jwt authenticator"
  type        = string
}
