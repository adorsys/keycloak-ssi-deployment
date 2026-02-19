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

variable "login_theme" {
  description = "Login theme for the realm"
  type        = string
  default     = "keycloak.v2+oid4vp"
}

variable "sdjwt_vct" {
  description = "Comma-separated list of VCT entries for sd-jwt authenticator"
  type        = string
}
