variable "keycloak_url" {
    description = "Keycloak base URL"
    type        = string
    default     = "http://localhost:8080"
}

variable "admin_password" {
    description = "Keycloak admin password"
    type        = string
    default     = "admin"
}
