output "client_scopes_applied_trigger" {
  description = "A trigger value that changes when the client scopes are applied."
  value       = { for k, v in null_resource.apply_custom_oid4vc_client_scopes : k => v.triggers.client_scope_hash }
}
