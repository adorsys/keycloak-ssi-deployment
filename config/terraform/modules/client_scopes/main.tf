resource "keycloak_openid_client_scope" "identity_credential" {
  name     = "IdentityCredential"
  protocol = "oid4vc"
  attributes = {
    vc.issuer_did = "https://localhost:8443/realms/oid4vc-vci"
    vc.credential_configuration_id = "IdentityCredential"
    vc.credential_contexts = "https://credentials.example.com/identity_credential"
    vc.credential_build_config.sd_jwt.visible_claims = "id,iat,nbf,exp,jti,status"
    vc.proof_signing_alg_values_supported = "ES256,ES384"
    vc.credential_build_config.hash_algorithm = "sha-256"
    vc.supported_credential_types = "identity_credential"
    vc.format = "dc+sd-jwt"
    include.in.token.scope = "true"
    vc.display = "[{\"name\": \"Identity Credential\"}]"
    vc.cryptographic_binding_methods_supported = "jwk"
    vc.expiry_in_seconds = "31536000"
    vc.verifiable_credential_type = "https://credentials.example.com/identity_credential"
    vc.include_in_metadata = "true"
    vc.credential_build_config.token_jws_type = "dc+sd-jwt"
    vc.sd_jwt.number_of_decoys = "2"
    vc.credential_identifier = "IdentityCredential"
  }
}

resource "keycloak_openid_client_scope_protocol_mapper" "identity_credential_mappers" {
  for_each = {
    given_name = {
      name = "given_name-mapper"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "vc.mandatory" = "false"
        "claim.name" = "given_name"
        "vc.display" = "[{\"name\":\"الاسم الشخصي\",\"locale\":\"ar\"},{\"name\":\"Vorname\",\"locale\":\"de\"},{\"name\":\"Given Name\",\"locale\":\"en\"},{\"name\":\"Nombre\",\"locale\":\"es\"},{\"name\":\"نام\",\"locale\":\"fa\"},{\"name\":\"Etunimi\",\"locale\":\"fi\"},{\"name\":\"Prénom\",\"locale\":\"fr\"},{\"name\":\"पहचानी गई नाम\",\"locale\":\"hi\"},{\"name\":\"Nome\",\"locale\":\"it\"},{\"name\":\"名\",\"locale\":\"ja\"},{\"name\":\"Овог нэр\",\"locale\":\"mn\"},{\"name\":\"Voornaam\",\"locale\":\"nl\"},{\"name\":\"Nome Próprio\",\"locale\":\"pt\"},{\"name\":\"Förnamn\",\"locale\":\"sv\"},{\"name\":\"مسلمان نام\",\"locale\":\"ur\"}]"
        "userAttribute" = "firstName"
      }
    }
    family_name = {
      name = "family_name-mapper"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "vc.mandatory" = "false"
        "claim.name" = "family_name"
        "vc.display" = "[{\"name\":\"اسم العائلة\",\"locale\":\"ar\"},{\"name\":\"Nachname\",\"locale\":\"de\"},{\"name\":\"Family Name\",\"locale\":\"en\"},{\"name\":\"Apellido\",\"locale\":\"es\"},{\"name\":\"نام خانوادگی\",\"locale\":\"fa\"},{\"name\":\"Sukunimi\",\"locale\":\"fi\"},{\"name\":\"Nom de famille\",\"locale\":\"fr\"},{\"name\":\"परिवार का नाम\",\"locale\":\"hi\"},{\"name\":\"Cognome\",\"locale\":\"it\"},{\"name\":\"姓\",\"locale\":\"ja\"},{\"name\":\"өөрийн нэр\",\"locale\":\"mn\"},{\"name\":\"Achternaam\",\"locale\":\"nl\"},{\"name\":\"Sobrenome\",\"locale\":\"pt\"},{\"name\":\"Efternamn\",\"locale\":\"sv\"},{\"name\":\"خاندانی نام\",\"locale\":\"ur\"}]"
        "userAttribute" = "lastName"
      }
    }
    status_list = {
      name = "status-list-claim-mapper"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-status-list-claim-mapper"
      consent_required = false
      config = {}
    }
    nbf = {
      name = "nbf-oid4vc-issued-at-time-claim-mapper-identity_credential"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-issued-at-time-claim-mapper"
      consent_required = false
      config = {
        "claim.name" = "nbf"
        "valueSource" = "COMPUTE"
      }
    }
    iat = {
      name = "iat-oid4vc-issued-at-time-claim-mapper-identity_credential"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-issued-at-time-claim-mapper"
      consent_required = false
      config = {
        "claim.name" = "iat"
        "truncateToTimeUnit" = "HOURS"
        "valueSource" = "COMPUTE"
      }
    }
    birthdate = {
      name = "birthdate-mapper"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "vc.mandatory" = "false"
        "claim.name" = "birthdate"
        "vc.display" = "[{\"name\":\"تاريخ الميلاد\",\"locale\":\"ar\"},{\"name\":\"Geburtsdatum\",\"locale\":\"de\"},{\"name\":\"Date of Birth\",\"locale\":\"en\"},{\"name\":\"Fecha de Nacimiento\",\"locale\":\"es\"},{\"name\":\"تاریخ تولد\",\"locale\":\"fa\"},{\"name\":\"Syntymäaika\",\"locale\":\"fi\"},{\"name\":\"Date de naissance\",\"locale\":\"fr\"},{\"name\":\"जन्म की तारीख\",\"locale\":\"hi\"},{\"name\":\"Data di nascita\",\"locale\":\"it\"},{\"name\":\"生年月日\",\"locale\":\"ja\"},{\"name\":\"төрсөн өдөр\",\"locale\":\"mn\"},{\"name\":\"Geboortedatum\",\"locale\":\"nl\"},{\"name\":\"Data de Nascimento\",\"locale\":\"pt\"},{\"name\":\"Födelsedatum\",\"locale\":\"sv\"},{\"name\":\"تاریخ پیدائش\",\"locale\":\"ur\"}]"
        "userAttribute" = "birthdate"
      }
    }
    username = {
      name = "username-mapper"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "username"
        "userAttribute" = "username"
      }
    }
  }
  # client_scope_id = keycloak_openid_client_scope.identity_credential.id
  name = each.value.name
  protocol = each.value.protocol
  protocol_mapper = each.value.protocol_mapper
  consent_required = each.value.consent_required
  config = each.value.config
}

resource "keycloak_openid_client_scope" "steuerberater_credential" {
  name     = "SteuerberaterCredential"
  protocol = "oid4vc"
  attributes = {
    vc.issuer_did = "https://localhost:8443/realms/oid4vc-vci"
    vc.credential_configuration_id = "SteuerberaterCredential"
    vc.credential_contexts = "stbk_westfalen_lippe"
    vc.credential_build_config.sd_jwt.visible_claims = "id,iat,nbf,exp,jti,status"
    vc.proof_signing_alg_values_supported = "ES256"
    vc.credential_build_config.hash_algorithm = "sha-256"
    vc.supported_credential_types = "stbk_westfalen_lippe"
    vc.format = "dc+sd-jwt"
    include.in.token.scope = "true"
    vc.display = "[{\"locale\":\"de-DE\",\"name\":\"Steuerberaterkammer Westfalen-Lippe\",\"logo\":{\"uri\":\"https://kci-portal.solutions.adorsys.com/credential_files/stbk-wl-icon.png\",\"alt_text\":\"Steuerberaterkammer Westfalen-Lippe\"},\"background_color\":\"#d3dce0\",\"text_color\":\"#000000\"},{\"locale\":\"en-US\",\"name\":\"Steuerberaterkammer Westfalen-Lippe\",\"logo\":{\"uri\":\"https://kci-portal.solutions.adorsys.com/credential_files/stbk-wl-icon.png\",\"alt_text\":\"Steuerberaterkammer Westfalen-Lippe\"},\"background_color\":\"#d3dce0\",\"text_color\":\"#000000\"}]"
    vc.cryptographic_binding_methods_supported = "jwk"
    vc.expiry_in_seconds = "31536000"
    vc.verifiable_credential_type = "stbk_westfalen_lippe"
    vc.include_in_metadata = "true"
    vc.credential_build_config.token_jws_type = "dc+sd-jwt"
    vc.sd_jwt.number_of_decoys = "2"
    vc.credential_identifier = "SteuerberaterCredential"
  }
}

resource "keycloak_openid_client_scope_protocol_mapper" "steuerberater_credential_mappers" {
  for_each = {
    address_country = {
      name = "address_country-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "address_country"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Staat\"},{\"locale\":\"en-US\",\"name\":\"Country\"},{\"locale\":\"fr-FR\",\"name\":\"Pays\"}]"
        "userAttribute" = "address_country"
      }
    }
    address_postal_code = {
      name = "address_postal_code-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "address_postal_code"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Wohnnort PLZ\"},{\"locale\":\"en-US\",\"name\":\"Postcode\"},{\"locale\":\"fr-FR\",\"name\":\"Code Postal\"}]"
        "userAttribute" = "address_postal_code"
      }
    }
    family_name = {
      name = "family_name-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "family_name"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Name\"},{\"locale\":\"en-US\",\"name\":\"Surname\"},{\"locale\":\"fr-FR\",\"name\":\"Nom\"}]"
        "userAttribute" = "lastName"
      }
    }
    status_list = {
      name = "status-list-claim-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-status-list-claim-mapper"
      consent_required = false
      config = {}
    }
    username = {
      name = "username-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "username"
        "userAttribute" = "username"
      }
    }
    address_street_address = {
      name = "address_street_address-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "address_street_address"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Wohnnort Straße\"},{\"locale\":\"en-US\",\"name\":\"Street\"},{\"locale\":\"fr-FR\",\"name\":\"Rue\"}]"
        "userAttribute" = "address_street_address"
      }
    }
    given_name = {
      name = "given_name-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "given_name"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Vornamen\"},{\"locale\":\"en-US\",\"name\":\"Given names\"},{\"locale\":\"fr-FR\",\"name\":\"Prènomes\"}]"
        "userAttribute" = "firstName"
      }
    }
    member_id = {
      name = "member_id-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "member_id"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Mitgliedsnummer\"},{\"locale\":\"en-US\",\"name\":\"Member ID\"},{\"locale\":\"fr-FR\",\"name\":\"Member ID\"}]"
        "userAttribute" = "member_id"
      }
    }
    nbf = {
      name = "nbf-oid4vc-issued-at-time-claim-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-issued-at-time-claim-mapper"
      consent_required = false
      config = {
        "claim.name" = "nbf"
        "valueSource" = "COMPUTE"
      }
    }
    date_of_birth = {
      name = "date_of_birth-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "date_of_birth"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Geburtstag\"},{\"locale\":\"en-US\",\"name\":\"Date of birth\"},{\"locale\":\"fr-FR\",\"name\":\"Date de naissance\"}]"
        "userAttribute" = "birthdate"
      }
    }
    address_locality = {
      name = "address_locality-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-user-attribute-mapper"
      consent_required = false
      config = {
        "claim.name" = "address_locality"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Wohnort Stadt\"},{\"locale\":\"en-US\",\"name\":\"City\"},{\"locale\":\"fr-FR\",\"name\":\"Ville\"}]"
        "userAttribute" = "address_locality"
      }
    }
    academic_title = {
      name = "academic_title-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-static-claim-mapper"
      consent_required = false
      config = {
        "claim.name" = "academic_title"
        "vc.display" = "[{\"locale\":\"de-DE\",\"name\":\"Titel\"},{\"locale\":\"en-US\",\"name\":\"Title\"},{\"locale\":\"fr-FR\",\"name\":\"Titre\"}]"
        "staticValue" = "N/A"
      }
    }
    iat = {
      name = "iat-oid4vc-issued-at-time-claim-mapper-bsk"
      protocol = "oid4vc"
      protocol_mapper = "oid4vc-issued-at-time-claim-mapper"
      consent_required = false
      config = {
        "claim.name" = "iat"
        "truncateToTimeUnit" = "HOURS"
        "valueSource" = "COMPUTE"
      }
    }
  }
  # client_scope_id = keycloak_openid_client_scope.steuerberater_credential.id
  name = each.value.name
  protocol = each.value.protocol
  protocol_mapper = each.value.protocol_mapper
  consent_required = each.value.consent_required
  config = each.value.config
}
