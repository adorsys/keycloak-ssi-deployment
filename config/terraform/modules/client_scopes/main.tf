terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}

locals {
  identity_credential_json      = file("${path.root}/jsons/scopes/client-scope-identity_credential.json")
  steuerberater_credential_json = file("${path.root}/jsons/scopes/client-scope-stbk_westfalen_lippe.json")
  kma_credential_json           = file("${path.root}/jsons/scopes/client-scope-kma_credential.json")
}

resource "null_resource" "apply_custom_oid4vc_client_scopes" {
  depends_on = [var.realm_id]

  triggers = {
    oid4vc_client_scopes_hash = join(",", [
      sha256(local.identity_credential_json),
      sha256(local.steuerberater_credential_json),
      sha256(local.kma_credential_json)
    ])
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      export KC_ADMIN_USER="admin"
      export KC_ADMIN_PASS="${var.admin_password}"
      export KC_URL="${var.keycloak_url}"
      export KC_REALM="master"

      TOKEN=$(curl -k -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$KC_ADMIN_USER" \
        -d "password=$KC_ADMIN_PASS" \
        -d "grant_type=password" | jq -r .access_token)

      echo "Importing OID4VC client scopes via curl..."

      # Import IdentityCredential scope
      cat <<EOF | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      ${local.identity_credential_json}
      EOF

      # Import SteuerberaterCredential scope
      cat <<EOF | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      ${local.steuerberater_credential_json}
      EOF

      # Import KMACredential scope
      cat <<EOF | curl -k -s -X POST "$KC_URL/admin/realms/${var.realm_name}/client-scopes" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @-
      ${local.kma_credential_json}
      EOF

      echo "Custom OID4VC client scopes imported."
    EOT
    interpreter = ["bash", "-c"]
  }
}
