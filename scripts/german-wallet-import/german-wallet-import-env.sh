#!/usr/bin/env bash
set -euo pipefail

gw_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gw_project_root="$(cd "$gw_script_dir/../.." && pwd)"
gw_runtime_dir="$gw_project_root/target/german-wallet-import"
trust_list_signing_certificate="$gw_runtime_dir/pid-provider-lote-signer.der"
trust_list_signing_certificate_url="https://bmi.usercontent.opencode.de/eudi-wallet/test-trust-lists/certificate.pem"
trust_list_signing_certificate_sha256="ee29b8c398635ddca1e5e9bd3670d131d3875cb5423c23f64f981e03d41e8fad"
trust_list_url="https://bmi.usercontent.opencode.de/eudi-wallet/test-trust-lists/pid-provider.jwt"
pid_provider_identifier="${GERMAN_WALLET_PID_PROVIDER_IDENTIFIER:-Bundesdruckerei GmbH}"
import_alias="oid4vp-import"
verifier_material_dir="${GERMAN_WALLET_VERIFIER_MATERIAL_DIR:-$gw_project_root/ec2_files}"
verifier_keystore="$verifier_material_dir/oid4vc-ecdsa-only.p12"
verifier_password_file="$verifier_material_dir/ecdsa_keystore.password"
verifier_key_alias="ecdsa_team_key"
verifier_public_key_sha256="7a252a19c160ed3c9d7cd53ac8b7c328abd71a8ed004608de7d2d0b7b480f49d"
verifier_config_source="$gw_project_root/infrastructure/terraform/secrets-26.6-updates.tfvars"

# shellcheck source=/dev/null
source "$gw_project_root/scripts/local-mdoc/local-mdoc-env.sh"

read_tfvars_string() {
  local variable_name="$1"
  sed -n "s/^${variable_name}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    "$verifier_config_source" | head -n 1
}

public_key_sha256_from_keystore() {
  keytool -exportcert \
    -alias "$verifier_key_alias" \
    -keystore "$verifier_keystore" \
    -storetype PKCS12 \
    -storepass:file "$verifier_password_file" \
    -rfc 2>/dev/null \
    | openssl x509 -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | sha256sum | cut -d' ' -f1
}

public_key_sha256_from_certificate() {
  local certificate="$1"
  printf '%s' "$certificate" \
    | base64 -d \
    | openssl x509 -inform DER -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | sha256sum | cut -d' ' -f1
}

prepare_verifier_identity() {
  [[ -f "$verifier_keystore" ]] || {
    echo "Missing recovered verifier keystore: $verifier_keystore" >&2
    exit 1
  }
  [[ -f "$verifier_password_file" ]] || {
    echo "Missing recovered verifier password file: $verifier_password_file" >&2
    exit 1
  }
  [[ -f "$verifier_config_source" ]] || {
    echo "Missing verifier certificate configuration: $verifier_config_source" >&2
    exit 1
  }
  chmod 600 "$verifier_keystore" "$verifier_password_file"

  local access_certificate registration_certificate keystore_key_hash certificate_key_hash
  access_certificate="$(read_tfvars_string oid4vp_access_certificate)"
  registration_certificate="$(read_tfvars_string oid4vp_registration_certificate)"
  [[ -n "$access_certificate" ]] || {
    echo "oid4vp_access_certificate is absent from $verifier_config_source" >&2
    exit 1
  }
  [[ -n "$registration_certificate" ]] || {
    echo "oid4vp_registration_certificate is absent from $verifier_config_source" >&2
    exit 1
  }

  keystore_key_hash="$(public_key_sha256_from_keystore)"
  certificate_key_hash="$(public_key_sha256_from_certificate "$access_certificate")"
  if [[ "$keystore_key_hash" != "$verifier_public_key_sha256" \
      || "$certificate_key_hash" != "$verifier_public_key_sha256" ]]; then
    echo "Recovered verifier key and configured access certificate do not match." >&2
    exit 1
  fi

  # The local harness expects its configured alias and password. Re-wrap only a
  # local ignored copy; never modify the recovered EC2 keystore.
  load_deployment_config
  local keystore_cache backup_keystore imported_keystore
  keystore_cache="$deployment_dir/src/utils/crypto/$(basename "$KEYSTORE_PATH")"
  backup_keystore="$runtime_dir/$(basename "$KEYSTORE_PATH").before-german-wallet"
  mkdir -p "$runtime_dir" "$(dirname "$keystore_cache")"
  if [[ -f "$keystore_cache" && ! -f "$backup_keystore" ]]; then
    cp -p "$keystore_cache" "$backup_keystore"
  fi
  imported_keystore="$(mktemp "$runtime_dir/verifier-keystore.XXXXXX.pkcs12")"
  rm -f "$imported_keystore"
  keytool -importkeystore -noprompt \
    -srckeystore "$verifier_keystore" \
    -srcstoretype PKCS12 \
    -srcstorepass:file "$verifier_password_file" \
    -srcalias "$verifier_key_alias" \
    -destkeystore "$imported_keystore" \
    -deststoretype PKCS12 \
    -deststorepass "$KEYSTORE_PASSWORD" \
    -destkeypass "$KEYSTORE_PASSWORD" \
    -destalias "$KEYSTORE_ALIASES_ECDSA_KEY" >/dev/null
  chmod 600 "$imported_keystore"
  mv "$imported_keystore" "$keystore_cache"

  export TF_VAR_oid4vp_client_identifier_prefix="x509_hash"
  export TF_VAR_sdjwt_access_certificate="$access_certificate"
  export TF_VAR_sdjwt_registration_certificate="$registration_certificate"
}

prepare_german_pid_trust() {
  mkdir -p "$gw_runtime_dir"
  local downloaded_pem downloaded_der
  downloaded_pem="$(mktemp "$gw_runtime_dir/lote-signer.XXXXXX.pem")"
  downloaded_der="$(mktemp "$gw_runtime_dir/lote-signer.XXXXXX.der")"
  if ! curl -fsSL "$trust_list_signing_certificate_url" -o "$downloaded_pem"; then
    rm -f "$downloaded_pem" "$downloaded_der"
    exit 1
  fi
  if ! openssl x509 -in "$downloaded_pem" -outform DER -out "$downloaded_der"; then
    rm -f "$downloaded_pem" "$downloaded_der"
    echo "The German sandbox LoTE signing certificate is not a valid PEM certificate." >&2
    exit 1
  fi
  rm -f "$downloaded_pem"
  echo "$trust_list_signing_certificate_sha256  $downloaded_der" | sha256sum --check --status || {
    rm -f "$downloaded_der"
    echo "German sandbox LoTE signing certificate checksum mismatch; refusing to configure trust." >&2
    exit 1
  }
  openssl x509 -inform DER -in "$downloaded_der" -noout -checkend 0 >/dev/null || {
    rm -f "$downloaded_der"
    echo "The pinned German sandbox LoTE signing certificate is expired or not yet valid." >&2
    exit 1
  }
  if ! openssl x509 -inform DER -in "$downloaded_der" -noout -checkend 2592000 >/dev/null; then
    echo "[WARN] The German sandbox LoTE signing certificate expires within 30 days; review the official sandbox trust-list publication." >&2
  fi
  mv "$downloaded_der" "$trust_list_signing_certificate"

  export TF_VAR_enable_german_wallet_import_test=true
  export TF_VAR_german_wallet_pid_trust_list_url="$trust_list_url"
  export TF_VAR_german_wallet_pid_trust_list_signing_certificate_path="$trust_list_signing_certificate"
  export TF_VAR_german_wallet_pid_provider_identifier="$pid_provider_identifier"
  export TF_VAR_oid4vp_import_idp_alias="$import_alias"
}

configure_import_provider() {
  KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD" \
    "$gw_script_dir/configure-import-provider.sh" \
    "$local_keycloak_url" oid4vc-vci "$import_alias"
}

configure_realm_user_profile() {
  KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD" \
    "$gw_script_dir/configure-realm-user-profile.sh" \
    "$local_keycloak_url" oid4vc-vci
}

verify_german_environment() {
  verify_environment
  local token execution_config_id import_provider_status
  token="$(curl -ksSf -X POST "$local_keycloak_url/realms/master/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode client_id=admin-cli --data-urlencode username=admin \
    --data-urlencode "password=$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD" \
    --data-urlencode grant_type=password | jq -er .access_token)"
  curl -ksSf "$local_keycloak_url/admin/realms/oid4vc-vci" \
    -H "Authorization: Bearer $token" \
    | jq -e '(.registrationEmailAsUsername // false) == false' >/dev/null
  import_provider_status="$(curl -ksS -o /dev/null -w '%{http_code}' \
    "$local_keycloak_url/admin/realms/oid4vc-vci/identity-provider/instances/$import_alias" \
    -H "Authorization: Bearer $token")"
  if [[ "$import_provider_status" != "200" ]]; then
    echo "Hidden import provider '$import_alias' is unavailable (HTTP $import_provider_status)." >&2
    echo "Run '$0 configure' before verification." >&2
    return 1
  fi
  curl -ksSf "$local_keycloak_url/admin/realms/oid4vc-vci/identity-provider/instances/$import_alias" \
    -H "Authorization: Bearer $token" \
    | jq -e '.enabled == true and .hideOnLogin == true and .providerId == "oid4vp-plugin-import"' >/dev/null
  curl -ksSf "$local_keycloak_url/admin/realms/oid4vc-vci/identity-provider/instances/$import_alias/mappers" \
    -H "Authorization: Bearer $token" \
    | jq -e '
        map(select(.identityProviderMapper == "oid4vp-user-attribute-idp-mapper"))
        | map(.name)
        | contains(["german-pid-username", "german-pid-given-name", "german-pid-family-name", "german-pid-birth-date", "german-pid-issuing-country"])
      ' >/dev/null
  curl -ksSf "$local_keycloak_url/admin/realms/oid4vc-vci/users/profile" \
    -H "Authorization: Bearer $token" \
    | jq -e '
        .unmanagedAttributePolicy == "ADMIN_VIEW"
        and ([.attributes[] | select(.name == "email" and has("required"))] | length == 0)
      ' >/dev/null
  execution_config_id="$(curl -ksSf \
    "$local_keycloak_url/admin/realms/oid4vc-vci/authentication/flows/oid4vp%20auth/executions" \
    -H "Authorization: Bearer $token" \
    | jq -er '.[] | select(.providerId == "oid4vp-authenticator") | .authenticationConfig')"
  curl -ksSf "$local_keycloak_url/admin/realms/oid4vc-vci/authentication/config/$execution_config_id" \
    -H "Authorization: Bearer $token" \
    | jq -e \
      --arg alias "$import_alias" \
      --arg trustListUrl "$trust_list_url" \
      --arg issuer "$pid_provider_identifier" '
        .config.importUnknownUsers == "true"
        and .config.importIdentityProviderAlias == $alias
        and .config.clientIdentifierPrefix == "x509_hash"
        and (.config.accessCertificate | length > 0)
        and (.config.registrationCertificate | length > 0)
        and (.config.profiles | fromjson | any(
          .id == "german-wallet-mdoc-import"
          and (.credentials | any(
            .id == "german-pid-mdoc"
            and (.trust | length == 1)
            and .trust[0].type == "eudi_pid_trust_list"
            and .trust[0].trustListUrl == $trustListUrl
            and (.trust[0].trustListSigningCertificate | length > 0)
            and .trust[0].serviceType == "http://uri.etsi.org/19602/SvcType/PID/Issuance"
            and .trust[0].issuer == $issuer
          ))
        ))
      ' >/dev/null
  echo "German wallet external-user import is ready."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-start}" in
    start)
      prepare_verifier_identity
      prepare_german_pid_trust
      start_environment
      configure_realm_user_profile
      configure_import_provider
      verify_german_environment
      ;;
    configure)
      prepare_verifier_identity
      prepare_german_pid_trust
      configure_environment
      configure_realm_user_profile
      configure_import_provider
      verify_german_environment
      ;;
    verify)
      prepare_verifier_identity
      prepare_german_pid_trust
      load_deployment_config
      verify_german_environment
      ;;
    stop)
      stop_environment
      ;;
    *)
      echo "Usage: $0 {start|configure|verify|stop}" >&2
      exit 1
      ;;
  esac
fi
