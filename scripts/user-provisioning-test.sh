#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/infrastructure/terraform"
TFVARS="$TF_DIR/secrets-user-provisioning-test.tfvars"
TF_DATA_DIR="$TF_DIR/.terraform-user-provisioning-test"
LOCAL_KEYCLOAK_ADMIN_URL="https://localhost:8443"
IMPORT_PROVIDER_RESOURCE='module.realm.null_resource.oid4vp_import_identity_provider[0]'
TRUST_CERT_URL="https://bmi.usercontent.opencode.de/eudi-wallet/test-trust-lists/certificate.pem"
TRUST_CERT_B64="$TF_DIR/.local-user-provisioning/german-pid-test-list-signing-certificate.b64"

usage() {
  cat <<'USAGE'
Usage: ./scripts/user-provisioning-test.sh <command>

Commands:
  start   Start local Keycloak with the provider JARs in the root providers/ directory.
  plan    Fetch the German sandbox trust-list signer certificate and plan a refresh of the import provider.
  apply   Apply the test configuration and recreate the import-provider setup resource.
  up      Start Keycloak, then apply the local Terraform configuration.
  links   Print request URLs for the Keycloak-issued and German PID profiles.
  stop    Stop local Keycloak while preserving its database.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

check_prerequisites() {
  for command in terraform curl jq openssl; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command"
  done

  if [[ ! -f "$TFVARS" ]]; then
    [[ -f "$TF_DIR/secrets-local.tfvars" ]] || fail "Create infrastructure/terraform/secrets-local.tfvars with the local Keycloak settings first."
    cp "$TF_DIR/secrets-local.tfvars" "$TFVARS"
  fi

  if grep -Eq '^[[:space:]]*oid4vp_user_provisioning_test_enabled[[:space:]]*=' "$TFVARS"; then
    sed -i -E 's/^[[:space:]]*oid4vp_user_provisioning_test_enabled[[:space:]]*=.*/oid4vp_user_provisioning_test_enabled = true/' "$TFVARS"
  else
    printf '\n# Enable the local OID4VP user-provisioning test profiles.\noid4vp_user_provisioning_test_enabled = true\n' >>"$TFVARS"
  fi
}

check_plugin_jar() {
  local -a jars=()
  mapfile -d '' -t jars < <(find "$ROOT/providers" -maxdepth 1 -type f -name 'keycloak-oid4vp-plugin-*.jar' -print0)
  [[ "${#jars[@]}" -eq 1 ]] || fail "Expected exactly one built keycloak-oid4vp-plugin-*.jar in providers/; found ${#jars[@]}. Build the feature branch JAR, replace the old JAR, and copy it there."
}

start_keycloak() {
  check_plugin_jar
  KC_SPI_KEYS__JAVA_KEYSTORE__KEYSTORES_PATH="$ROOT/ec2_files" \
    "$ROOT/keycloak-ssi.sh" setup -d
  echo "Waiting for local Keycloak..."
  local attempt
  for attempt in {1..60}; do
    if curl --silent --insecure --fail https://localhost:8443/realms/master/.well-known/openid-configuration >/dev/null; then
      echo "Local Keycloak is ready at https://localhost:8443."
      return
    fi
    sleep 2
  done
  fail "Keycloak did not become ready at https://localhost:8443. Check the startup logs."
}

prepare_terraform() {
  check_prerequisites

  local keycloak_url
  keycloak_url="$(sed -nE 's/^keycloak_url[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$TFVARS" | head -n 1)"
  [[ -n "$keycloak_url" ]] || fail "Could not read keycloak_url from $TFVARS."
  curl --silent --insecure --fail "${keycloak_url%/}/realms/master/.well-known/openid-configuration" >/dev/null \
    || fail "Keycloak is not reachable at $keycloak_url. Start the local HTTPS tunnel configured in $TFVARS and try again."

  mkdir -p "$(dirname "$TRUST_CERT_B64")"

  local pem_file="$TF_DIR/.local-user-provisioning/german-pid-test-list-signing-certificate.pem"
  curl --silent --show-error --fail --location "$TRUST_CERT_URL" --output "$pem_file"
  openssl x509 -in "$pem_file" -noout >/dev/null || fail "The downloaded German sandbox trust-list certificate is not a valid X.509 certificate."
  openssl x509 -in "$pem_file" -outform DER | base64 --wrap=0 >"$TRUST_CERT_B64"

  if [[ ! -f "$TF_DIR/backend_override.tf" ]]; then
    cp "$TF_DIR/backend_override.tf.example" "$TF_DIR/backend_override.tf"
  fi

  TF_DATA_DIR="$TF_DATA_DIR" terraform -chdir="$TF_DIR" init -reconfigure
}

terraform_plan() {
  prepare_terraform
  TF_DATA_DIR="$TF_DATA_DIR" terraform -chdir="$TF_DIR" plan \
    -replace="$IMPORT_PROVIDER_RESOURCE" \
    -var-file="$TFVARS" \
    -var="keycloak_url=$LOCAL_KEYCLOAK_ADMIN_URL"
}

terraform_apply() {
  prepare_terraform
  TF_DATA_DIR="$TF_DATA_DIR" terraform -chdir="$TF_DIR" apply \
    -replace="$IMPORT_PROVIDER_RESOURCE" \
    -var-file="$TFVARS" \
    -var="keycloak_url=$LOCAL_KEYCLOAK_ADMIN_URL"
}

print_request_links() {
  check_prerequisites
  local keycloak_url realm
  keycloak_url="$(sed -nE 's/^keycloak_url[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$TFVARS" | head -n 1)"
  realm="$(sed -nE 's/^realm[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$TFVARS" | head -n 1)"
  [[ -n "$keycloak_url" && -n "$realm" ]] || fail "Could not read keycloak_url and realm from $TFVARS."
  local endpoint="${keycloak_url%/}/realms/$realm/oid4vp-auth/request?client_id=oid4vc-demo-public&profile_id="
  echo "Keycloak-issued credential: ${endpoint}keycloak-issued"
  echo "German PID import:          ${endpoint}german-pid-import"
  echo
  echo "Open either URL in a browser to get the wallet authorization link. The German PID URL must be reachable by the wallet over HTTPS."
}

command="${1:-help}"
case "$command" in
  start)
    start_keycloak
    ;;
  plan)
    terraform_plan
    ;;
  apply)
    terraform_apply
    ;;
  up)
    start_keycloak
    terraform_apply
    print_request_links
    ;;
  links)
    print_request_links
    ;;
  stop)
    "$ROOT/keycloak-ssi.sh" stop
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    fail "Unknown command: $command"
    ;;
esac
