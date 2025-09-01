resource "keycloak_openid_client" "openid4vc_rest_api" {
  client_id                    = "openid4vc-rest-api"
  name                         = "openid4vc-rest-api"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  valid_redirect_uris = [
    "https://issuer.eudi-adorsys.com/services",
    "https://localhost:8443/callback",
    "http://back.localhost.com/*"
  ]
  web_origins = [
    "https://issuer.eudi-adorsys.com/services",
    "https://localhost:8443"
  ]
  client_secret = var.client_secret
  optional_scopes = [
    "IdentityCredential",
    "SteuerberaterCredential"
  ]
  attributes = {
    "oid4vci.enabled" = "true"
    "client.secret.creation.time" = "1719785014"
    "post.logout.redirect.uris" = "http://front.localhost.com##https://issuer.eudi-adorsys.com/*##https://issuer.eudi-adorsys.com"
  }
}
