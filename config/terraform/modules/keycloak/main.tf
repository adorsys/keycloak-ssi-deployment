resource "keycloak_realm" "oid4vc_vci" {
  realm   = var.realm
  enabled = true
}

resource "keycloak_openid_client" "openid4vc_rest_api" {
  realm_id                     = keycloak_realm.oid4vc_vci.id
  client_id                    = "openid4vc-rest-api"
  name                         = "openid4vc-rest-api"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true

  valid_redirect_uris = [
    "https://localhost:8443/callback",
    "https://issuer.eudi-adorsys.com/services/*",
    "http://back.localhost.com/*"
  ]
  web_origins = [
    "https://issuer.eudi-adorsys.com/services",
    "https://localhost:8443"
  ]
  client_secret = "uArydomqOymeF0tBrtipkPYujNNUuDlt"
}

resource "keycloak_openid_client_default_scopes" "openid4vc_rest_api_defaults" {
  realm_id  = keycloak_realm.oid4vc_vci.id
  client_id = keycloak_openid_client.openid4vc_rest_api.id
  default_scopes = [
    "web-origins",
    "acr",
    "profile",
    "roles",
    "basic",
    "email"
  ]
}

resource "keycloak_openid_client_optional_scopes" "openid4vc_rest_api_optional" {
  realm_id  = keycloak_realm.oid4vc_vci.id
  client_id = keycloak_openid_client.openid4vc_rest_api.id
  optional_scopes = [
    "address",
    "identity_credential",
    "phone",
    "offline_access",
    "microprofile-jwt",
    "stbk_westfalen_lippe"
  ]
}

resource "null_resource" "apply_custom_oid4vc_key_components" {
  depends_on = [keycloak_realm.oid4vc_vci]

  triggers = {
    oid4vc_key_components_hash = join(",", [for f in fileset("${path.module}/json/keys", "*.json") : filesha1("${path.module}/json/keys/${f}")])
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="admin"
      export KC_URL="http://localhost:8080"
      export KC_REALM="master"
      export TOKEN=$(curl -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)
      echo "Importing OID4VC key components via curl..."
      for json in ${path.module}/json/keys/*.json; do
        echo "Importing $json ..."
        curl -s -X POST "$KC_URL/admin/realms/oid4vc-vci/components" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary "@$json"
      done
      echo "Custom OID4VC key components imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  depends_on = [keycloak_realm.oid4vc_vci]

  triggers = {
    oid4vc_client_scopes_hash = join(",", [for f in fileset("${path.module}/json/scopes", "*.json") : filesha1("${path.module}/json/scopes/${f}")])
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="admin"
      export KC_URL="http://localhost:8080"
      export KC_REALM="master"
      export TOKEN=$(curl -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)
      echo "Importing OID4VC client scopes via curl..."
      for json in ${path.module}/json/scopes/*.json; do
        echo "Importing $json ..."
        curl -s -X POST "$KC_URL/admin/realms/oid4vc-vci/client-scopes" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary "@$json"
      done
      echo "Custom OID4VC client scopes imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}