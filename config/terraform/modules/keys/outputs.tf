output "keys_applied" {
  description = "Whether the OID4VC key components have been applied"
  value       = null_resource.apply_custom_oid4vc_key_components.id
}
