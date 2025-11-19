output "client_ids" {
  description = "The IDs of the created clients"
  value       = { for k, v in keycloak_openid_client.clients : k => v.id }
}
