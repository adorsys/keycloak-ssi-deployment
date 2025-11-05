output "client_scopes_applied" {
  description = "Whether the OID4VC client scopes have been applied"
  value       = null_resource.apply_custom_oid4vc_client_scopes.id
}
