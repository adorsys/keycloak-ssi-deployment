output "realm_id" {
  description = "The ID of the created realm"
  value       = keycloak_realm.oid4vc_vci.id

  depends_on = [
    keycloak_realm.oid4vc_vci,
    null_resource.set_realm_browser_flow,
    null_resource.enable_verifiable_credentials
  ]
}

output "realm_name" {
  description = "The name of the created realm"
  value       = keycloak_realm.oid4vc_vci.realm
}

output "verifiable_credentials_enabled" {
  description = "Whether verifiable credentials have been enabled for the realm"
  value       = true
  depends_on  = [null_resource.enable_verifiable_credentials]
}
