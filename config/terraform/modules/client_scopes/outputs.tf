output "identity_credential_scope_id" {
  value = keycloak_openid_client_scope.identity_credential.id
}

output "steuerberater_credential_scope_id" {
  value = keycloak_openid_client_scope.steuerberater_credential.id
}
