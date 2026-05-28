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

variable "max_mustermann_username" {
  description = "User name for the Max Mustermann payslip demo user"
  type        = string
  default     = "max_mustermann"
}

variable "max_mustermann_first_name" {
  description = "First name for the Max Mustermann payslip demo user"
  type        = string
  default     = "Max"
}

variable "max_mustermann_last_name" {
  description = "Last name for the Max Mustermann payslip demo user"
  type        = string
  default     = "Mustermann"
}

variable "max_mustermann_email" {
  description = "Email for the Max Mustermann payslip demo user"
  type        = string
  default     = "maxmustermann@mail.de"
}

variable "max_mustermann_initial_password" {
  description = "Initial password for the Max Mustermann payslip demo user"
  type        = string
  sensitive   = true
}
