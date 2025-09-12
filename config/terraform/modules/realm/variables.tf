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
