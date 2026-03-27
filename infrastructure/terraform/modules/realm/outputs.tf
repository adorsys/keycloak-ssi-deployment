output "realm_id" {
  value      = keycloak_realm.oid4vc_vci.id
  depends_on = [null_resource.enable_verifiable_credentials]
}
