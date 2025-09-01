output "rsa_issuer_key_id" {
  value = keycloak_key_provider.rsa_issuer_key.id
}
output "rsa_encryption_key_id" {
  value = keycloak_key_provider.rsa_encryption_key.id
}
output "ecdsa_issuer_key_id" {
  value = keycloak_key_provider.ecdsa_issuer_key.id
}
