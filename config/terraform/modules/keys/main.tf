resource "keycloak_key_provider" "rsa_issuer_key" {
  name       = "rsa-issuer-key"
  provider_id = "java-keystore"
  config = {
    keystorePassword = var.keystore_password
    keyAlias         = "rsa_sig_key"
    keyPassword      = var.keystore_password
    keystoreType     = "PKCS12"
    active           = "true"
    keystore         = var.keystore_path
    priority         = "0"
    enabled          = "true"
    algorithm        = "RS256"
  }
}

resource "keycloak_key_provider" "rsa_encryption_key" {
  name       = "rsa-encryption-key"
  provider_id = "java-keystore"
  config = {
    keystorePassword = var.keystore_password
    keyAlias         = "rsa_enc_key"
    keystoreType     = "PKCS12"
    keyUse           = "enc"
    keyPassword      = var.keystore_password
    active           = "true"
    keystore         = var.keystore_path
    priority         = "0"
    enabled          = "true"
    algorithm        = "RSA-OAEP"
  }
}

resource "keycloak_key_provider" "ecdsa_issuer_key" {
  name       = "ecdsa-issuer-key"
  provider_id = "java-keystore"
  config = {
    keystorePassword = var.keystore_password
    keyAlias         = "ecdsa_key"
    keyPassword      = var.keystore_password
    keystoreType     = "PKCS12"
    active           = "true"
    keystore         = var.keystore_path
    priority         = "0"
    enabled          = "true"
    algorithm        = "ES256"
  }
}
