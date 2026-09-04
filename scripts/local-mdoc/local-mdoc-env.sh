#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
deployment_dir="$project_root/keycloak-oauth-sig/oid4vci-deployment"
plugin_source="${OID4VP_PLUGIN_SOURCE_DIR:-/home/adorsys/adorsys_dev/keycloak-oid4vp-plugin}"
runtime_dir="$project_root/target/local-mdoc"
terraform_data_dir="$runtime_dir/terraform-data"
terraform_work_dir="$runtime_dir/terraform-work"
terraform_state="$runtime_dir/terraform.tfstate"
terraform_secrets="$project_root/infrastructure/terraform/secrets-local.tfvars"
provider_id="urn:adorsys:local:pid-provider:keycloak"
local_keycloak_url="https://localhost:10443"

load_deployment_config() {
  export WORK_DIR="$deployment_dir"
  if [[ -f "$project_root/config-override.yaml" ]]; then
    cp "$project_root/config-override.yaml" "$deployment_dir/config.override.yaml"
  fi
  # shellcheck source=/dev/null
  source "$deployment_dir/src/utils/helper.sh"
  setup_environment
  ensure_keycloak_install_dir_resolved
}

build_plugin() {
  [[ -d "$plugin_source" ]] || { echo "OID4VP plugin source not found: $plugin_source" >&2; exit 1; }

  local mvn_cmd="$plugin_source/mvnw"
  if [[ ! -x "$mvn_cmd" ]]; then
    if command -v mvn >/dev/null 2>&1; then
      mvn_cmd="mvn"
    else
      echo "Maven or mvnw not found for OID4VP plugin at $plugin_source" >&2
      exit 1
    fi
  fi

  # Clean any stale symlink at keycloak_main left by previous local checkouts
  local staged_source="$deployment_dir/target/keycloak_main"
  if [[ -L "$staged_source" ]]; then
    echo "Removing stale symlink at $staged_source"
    rm -f "$staged_source"
  fi

  echo "Building OID4VP plugin from $plugin_source..."
  (cd "$plugin_source" && "$mvn_cmd" clean package -DskipTests)

  local built_jar
  built_jar="$(find "$plugin_source/target" -maxdepth 1 -name 'keycloak-oid4vp-plugin-*.jar' ! -name '*sources*' ! -name '*javadoc*' | head -n 1)"
  if [[ -z "$built_jar" ]]; then
    echo "Built plugin JAR not found in $plugin_source/target" >&2
    exit 1
  fi
  mkdir -p "$project_root/providers"
  cp "$built_jar" "$project_root/providers/keycloak-oid4vp-plugin-1.1.9.jar"
  echo "Staged plugin JAR to $project_root/providers/keycloak-oid4vp-plugin-1.1.9.jar"
}

start_lote_server() {
  mkdir -p "$runtime_dir"
  if [[ -f "$runtime_dir/lote-server.pid" ]]; then
    local old_pid
    old_pid="$(cat "$runtime_dir/lote-server.pid")"
    if kill -0 "$old_pid" 2>/dev/null; then
      kill "$old_pid" 2>/dev/null || true
      for _ in $(seq 1 10); do
        kill -0 "$old_pid" 2>/dev/null || break
        sleep 0.2
      done
      kill -9 "$old_pid" 2>/dev/null || true
    fi
    rm -f "$runtime_dir/lote-server.pid"
  fi

  fuser -k 9443/tcp 2>/dev/null || true
  pkill -f 'serve-test-lote.py' 2>/dev/null || true
  sleep 0.5

  "$script_dir/generate-test-lote.sh" \
    "$runtime_dir" "$KEYSTORE_PATH" "$KEYSTORE_PASSWORD" "$KEYSTORE_ALIASES_ECDSA_KEY" "$provider_id"

  nohup python3 "$script_dir/serve-test-lote.py" \
    --directory "$runtime_dir" \
    --certificate "$SSL_SERVER_CERT" \
    --private-key "$SSL_SERVER_KEY" \
    --port 9443 >"$runtime_dir/lote-server.log" 2>&1 &
  echo "$!" > "$runtime_dir/lote-server.pid"

  for _ in $(seq 1 40); do
    if curl -ksSf "https://localhost:9443/pid-providers.jwt" >/dev/null 2>&1; then
      echo "[SUCCESS] Local LoTE server is ready on https://localhost:9443"
      return
    fi
    sleep 0.5
  done
  echo "The local LoTE server did not become ready; see $runtime_dir/lote-server.log" >&2
  exit 1
}

stop_existing_instance() {
  echo "[INFO] Checking for a running Keycloak instance before starting a fresh one..."

  # Kill any running Keycloak process (kc.sh / java QuarkusEntryPoint)
  local kc_pid
  kc_pid="$(pgrep -f '[k]c\.sh start|java.*([K]eycloakMain|[Q]uarkusEntryPoint)' | head -n 1 || true)"
  if [[ -n "$kc_pid" ]]; then
    echo "[INFO] Found Keycloak process (PID: $kc_pid). Sending SIGTERM..."
    kill "$kc_pid" 2>/dev/null || true
    # Wait up to 10 s for graceful shutdown
    local i
    for i in $(seq 1 10); do
      if ! kill -0 "$kc_pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    # Force-kill if still alive
    if kill -0 "$kc_pid" 2>/dev/null; then
      echo "[WARN] Graceful shutdown timed out; sending SIGKILL..."
      kill -9 "$kc_pid" 2>/dev/null || true
      sleep 1
    fi
    echo "[INFO] Keycloak process stopped."
  else
    echo "[INFO] No running Keycloak process detected."
  fi

  # Also bring down the database container and remove its volume to get a clean state
  local compose_dir="$deployment_dir"
  local compose_file=""
  if [[ -f "$compose_dir/docker-compose.yaml" ]]; then
    compose_file="$compose_dir/docker-compose.yaml"
  elif [[ -f "$compose_dir/docker-compose.yml" ]]; then
    compose_file="$compose_dir/docker-compose.yml"
  fi
  if command -v docker >/dev/null 2>&1 && [[ -n "$compose_file" ]]; then
    echo "[INFO] Tearing down existing database container (if any)..."
    docker compose -f "$compose_file" down -v 2>/dev/null || true
  fi

  # Also clean up any existing LoTE server
  if [[ -f "$runtime_dir/lote-server.pid" ]]; then
    local lote_pid
    lote_pid="$(cat "$runtime_dir/lote-server.pid")"
    kill "$lote_pid" 2>/dev/null || true
    rm -f "$runtime_dir/lote-server.pid"
  fi
  fuser -k 9443/tcp 2>/dev/null || true
  pkill -f 'serve-test-lote.py' 2>/dev/null || true
}

wait_for_keycloak() {
  for _ in $(seq 1 120); do
    if curl -ksSf "$local_keycloak_url/realms/master" >/dev/null; then
      return
    fi
    sleep 2
  done
  echo "Keycloak did not become ready; see $deployment_dir/target/keycloak.log" >&2
  exit 1
}

apply_terraform() {
  [[ -f "$terraform_secrets" ]] || {
    echo "Missing $terraform_secrets; create it from your local secret values first." >&2
    exit 1
  }

  export TF_DATA_DIR="$terraform_data_dir"
  export TF_VAR_keycloak_url="$local_keycloak_url"
  export TF_VAR_admin_password="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"
  export TF_VAR_enable_local_mdoc_test=true
  export TF_VAR_local_mdoc_trust_list_url="https://localhost:9443/pid-providers.jwt"
  export TF_VAR_local_mdoc_trust_list_signing_certificate_path="$runtime_dir/lote-signing.crt.der"
  export TF_VAR_local_pid_provider_identifier="$provider_id"
  export TF_VAR_oid4vc_issuer_keystore_path="$KEYSTORE_PATH"
  export TF_VAR_oid4vc_issuer_keystore_type="$KEYSTORE_TYPE"
  export TF_VAR_oid4vc_issuer_keystore_password="$KEYSTORE_PASSWORD"
  export TF_VAR_oid4vc_issuer_key_alias="$KEYSTORE_ALIASES_ECDSA_KEY"

  # The repository backend is S3. Keep this disposable local test isolated by
  # materializing the same configuration without backend.tf under target/.
  mkdir -p "$terraform_work_dir"
  rsync -a --delete --exclude='backend.tf' \
    "$project_root/infrastructure/terraform/" "$terraform_work_dir/"

  terraform -chdir="$terraform_work_dir" init -reconfigure

  local -a tf_vars=(
    -var-file="$terraform_secrets"
    -var="keycloak_url=$local_keycloak_url"
    -var="admin_password=$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"
  )

  if [[ -n "${CREDENTIALS_ENABLED:-}" ]]; then
    local scope_names_json
    scope_names_json="$(jq -cn --arg enabled "$CREDENTIALS_ENABLED" '
      $enabled | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
    ')"
    export TF_VAR_enabled_scope_names="$scope_names_json"
    tf_vars+=(-var="enabled_scope_names=$scope_names_json")
  fi

  adopt_existing_realm() {
    local tf_state_resources
    tf_state_resources="$(terraform -chdir="$terraform_work_dir" state list \
      -state="$terraform_state" 2>/dev/null || true)"
    if curl -ksSf "$local_keycloak_url/realms/oid4vc-vci" >/dev/null \
        && ! grep -Fxq 'module.realm.keycloak_realm.oid4vc_vci' <<<"$tf_state_resources"; then
      terraform -chdir="$terraform_work_dir" import -state="$terraform_state" \
        "${tf_vars[@]}" module.realm.keycloak_realm.oid4vc_vci oid4vc-vci
    fi
  }

  adopt_existing_realm
  if ! terraform -chdir="$terraform_work_dir" apply -state="$terraform_state" \
      -auto-approve "${tf_vars[@]}"; then
    # Realm creation invokes the OID4VP migration listener. On a slow first
    # boot, the provider can retry the POST and receive 409 although creation
    # succeeded. Adopt that realm and resume the same declarative apply.
    adopt_existing_realm
    terraform -chdir="$terraform_work_dir" apply -state="$terraform_state" \
      -auto-approve "${tf_vars[@]}"
  fi
}

verify_environment() {
  curl -ksSf "https://localhost:9443/pid-providers.jwt" >/dev/null
  if [[ -z "${CREDENTIALS_ENABLED:-}" ]] || [[ ",${CREDENTIALS_ENABLED:-}," == *",PIDCredential,"* ]]; then
    curl -ksSf "$local_keycloak_url/realms/oid4vc-vci/.well-known/openid-credential-issuer" \
      | jq -e '.credential_configurations_supported.PIDCredential.format == "mso_mdoc"' >/dev/null
  fi
  echo "Local mDoc environment is ready."
  echo "Issuer metadata: $local_keycloak_url/realms/oid4vc-vci/.well-known/openid-credential-issuer"
  echo "Signed PID LoTE: https://localhost:9443/pid-providers.jwt"
  echo "PID Provider identifier: $provider_id"
}

start_environment() {
  load_deployment_config
  # Always shut down any existing Keycloak instance first to avoid port conflicts
  stop_existing_instance
  local kc_features="${KEYCLOAK_FEATURES:-oid4vc-vci}"
  if [[ -z "${CREDENTIALS_ENABLED:-}" ]] || [[ ",${CREDENTIALS_ENABLED:-}," == *",PIDCredential,"* ]]; then
    if [[ ",$kc_features," != *",oid4vc-mdoc,"* ]]; then
      kc_features="$kc_features,oid4vc-mdoc"
    fi
  fi
  build_plugin
  OID4VP_ONLY=true KEYCLOAK_FEATURES="$kc_features" "$project_root/keycloak-ssi.sh" setup -d
  start_lote_server
  wait_for_keycloak
  apply_terraform
  verify_environment
}

configure_environment() {
  load_deployment_config
  start_lote_server
  wait_for_keycloak
  apply_terraform
  verify_environment
}

stop_environment() {
  if [[ -f "$runtime_dir/lote-server.pid" ]]; then
    local lote_pid
    lote_pid="$(cat "$runtime_dir/lote-server.pid")"
    kill "$lote_pid" 2>/dev/null || true
    rm -f "$runtime_dir/lote-server.pid"
  fi
  fuser -k 9443/tcp 2>/dev/null || true
  pkill -f 'serve-test-lote.py' 2>/dev/null || true
  "$project_root/keycloak-ssi.sh" stop
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-start}" in
    start) start_environment ;;
    configure) configure_environment ;;
    refresh-lote)
      load_deployment_config
      start_lote_server
      ;;
    verify) verify_environment ;;
    stop) stop_environment ;;
    *) echo "Usage: $0 {start|configure|refresh-lote|verify|stop}" >&2; exit 1 ;;
  esac
fi
