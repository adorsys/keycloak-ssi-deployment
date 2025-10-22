output "keys_applied" {
  description = "Whether the OID4VC key components have been applied"
  value       = null_resource.apply_custom_oid4vc_key_components.id
}

output "generated_keys_disabled" {
  description = "Whether the automatically generated Keycloak keys (RSA-OAEP and RS256) have been disabled"
  value       = null_resource.disable_generated_keys.id
}
