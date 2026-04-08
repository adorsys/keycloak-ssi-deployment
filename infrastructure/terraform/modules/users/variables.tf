variable "realm_id" {
  description = "Keycloak realm ID"
  type        = string
}

variable "username" {
  description = "User name"
  type        = string
  default     = "francis"
}

variable "first_name" {
  description = "User first name"
  type        = string
  default     = "Francis"
}

variable "last_name" {
  description = "User last name"
  type        = string
  default     = "Pouatcha"
}

variable "email" {
  description = "User email"
  type        = string
  default     = "fpo@mail.de"
}

variable "initial_password" {
  description = "Initial password for user"
  type        = string
}
