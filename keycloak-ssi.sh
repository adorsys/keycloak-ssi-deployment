#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Keycloak SSI Deployment Wrapper
# =============================================================================
# Wraps the submodule CLI and adds infrastructure management (Terraform/Helm)
# =============================================================================

# Determine project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DEPLOYMENT_DIR="$PROJECT_ROOT/keycloak-oauth-sig/oid4vci-deployment"
SUBMODULE_CLI="$TEST_DEPLOYMENT_DIR/keycloak-ssi.sh"

# Colors
if [ -t 1 ]; then
  CLI_GREEN="$(printf '\033[0;32m')"
  CLI_YELLOW="$(printf '\033[1;33m')"
  CLI_BLUE="$(printf '\033[1;34m')"
  CLI_RED="$(printf '\033[0;31m')"
  CLI_NC="$(printf '\033[0m')"
else
  CLI_GREEN=""; CLI_YELLOW=""; CLI_BLUE=""; CLI_RED=""; CLI_NC="";
fi

log() { echo -e "${CLI_BLUE}[WRAPPER]${CLI_NC} $1"; }
warn() { echo -e "${CLI_YELLOW}[WARN]${CLI_NC} $1"; }
error() { echo -e "${CLI_RED}[ERROR]${CLI_NC} $1"; exit 1; }

# =============================================================================
# Helper Functions
# =============================================================================

sync_providers() {
    local src="$PROJECT_ROOT/providers"
    local dest="$TEST_DEPLOYMENT_DIR/providers"

    if [[ -d "$src" && "$(ls -A "$src")" ]]; then
        log "Syncing custom providers from $src to $dest..."
        mkdir -p "$dest"
        cp "$src"/*.jar "$dest/"
    else
        log "No custom providers found in $src, skipping sync."
    fi
}

sync_config() {
    local src="$PROJECT_ROOT/config-override.yaml"
    local dest="$TEST_DEPLOYMENT_DIR/config.override.yaml"

    if [[ -f "$src" ]]; then
        log "Applying configuration override from $src..."
        cp "$src" "$dest"
    else

        if [[ -f "$dest" ]]; then
            log "No config-override.yaml found in root, removing stale override from submodule."
            rm -f "$dest"
        fi
    fi
}

sync_all() {
    sync_providers
    sync_config
}

check_submodule() {
    if [[ ! -f "$SUBMODULE_CLI" ]]; then
        error "Submodule CLI not found at $SUBMODULE_CLI.\nDid you run 'git submodule update --init --recursive'?"
    fi
}

# =============================================================================
# Submodule Extended Commands
# =============================================================================

cmd_scopes() {
    check_submodule
    sync_config
    log "Configuring client scopes independently..."
    
    (cd "$TEST_DEPLOYMENT_DIR" && bash -c "
        S_GREEN=\"\$(printf '\033[0;32m')\"
        S_YELLOW=\"\$(printf '\033[1;33m')\"
        S_BLUE=\"\$(printf '\033[1;34m')\"
        S_RED=\"\$(printf '\033[0;31m')\"
        S_NC=\"\$(printf '\033[0m')\"

        source src/utils/helper.sh
        setup_environment
        ensure_keycloak_install_dir_resolved
        
        if ! curl -k -s \"\$KEYCLOAK_ADMIN_ADDR/realms/master\" >/dev/null 2>&1; then
            echo -e \"\${S_RED}[ERROR]\${S_NC} Keycloak is not running. Start it first using './keycloak-ssi.sh setup'.\"
            exit 1
        fi
        
        KCADM=\"\$KEYCLOAK_INSTALL_DIR/bin/kcadm.sh\"
        if [[ ! -x \"\$KCADM\" ]]; then
            echo -e \"\${S_RED}[ERROR]\${S_NC} kcadm.sh not found at: \$KCADM\"
            exit 1
        fi

        \"\$KCADM\" config truststore --trustpass \"\$SSL_TRUST_STORE_PASS\" \"\$SSL_TRUST_STORE\" >/dev/null 2>&1
        \"\$KCADM\" config credentials --server \"\$KEYCLOAK_ADMIN_ADDR\" --realm master \
            --user \"\$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME\" --password \"\$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD\" >/dev/null 2>&1

        echo -e \"\${S_BLUE}[INFO]\${S_NC} Creating client scopes in realm '\$KEYCLOAK_REALM'...\"
        
        SCOPE_FILE=\"src/config/client-scope-config.json\"
        if [[ -f \"\$SCOPE_FILE\" ]]; then
            # Inject Issuer DID and process each scope
            CLIENT_SCOPES_CONFIG=\$(jq --arg ISSUER_DID \"\$KEYCLOAK_ISSUER_DID\" 'map(.attributes[\"vc.issuer_did\"] = \$ISSUER_DID)' \"\$SCOPE_FILE\")
            
            echo \"\$CLIENT_SCOPES_CONFIG\" | jq -c '.[]' | while read -r scope; do
                SCOPE_NAME=\$(echo \"\$scope\" | jq -r .name)
                if echo \"\$scope\" | \"\$KCADM\" create client-scopes -r \"\$KEYCLOAK_REALM\" -f - >/dev/null 2>&1; then
                    echo -e \"\${S_GREEN}[SUCCESS]\${S_NC} Client scope '\$SCOPE_NAME' created successfully.\"
                else
                    echo -e \"\${S_YELLOW}[INFO]\${S_NC} Client scope '\$SCOPE_NAME' already exists (skipping).\"
                fi
            done
        else
            echo -e \"\${S_RED}[ERROR]\${S_NC} Scope configuration file not found at \$SCOPE_FILE\"
            exit 1
        fi
    ")
}

# =============================================================================


cmd_terraform() {
    local tf_dir="$PROJECT_ROOT/infrastructure/terraform"
    log "Delegating to Terraform in $tf_dir..."
    
    if [[ ! -d "$tf_dir" ]]; then
        error "Terraform directory not found at $tf_dir"
    fi

    (cd "$tf_dir" && terraform "$@")
}

cmd_helm() {
    local helm_dir="$PROJECT_ROOT/infrastructure/keycloak-chart"
    log "Delegating to Helm (context: $helm_dir)..."
    
    if [[ ! -d "$helm_dir" ]]; then
        error "Helm chart directory not found at $helm_dir"
    fi

    # We'll just run helm in the chart dir for convenience, though helm usually runs from anywhere with paths.
    (cd "$helm_dir" && helm "$@")
}

# =============================================================================
# Main
# =============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    if ! command -v figlet >/dev/null 2>&1; then
        function figlet() {
            local last_arg=""
            for arg in "$@"; do
                if [[ "$arg" != -* ]]; then
                    last_arg="$arg"
                fi
            done
            [ -n "$last_arg" ] && echo "$last_arg"
        }
        export -f figlet
    fi

    case "$cmd" in
        setup)
            check_submodule
            sync_all
            log "Delegating 'setup' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" setup "$@")
            ;;
        
        config)
            check_submodule
            sync_config
            log "Delegating 'config' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" config "$@")
            ;;

        test)
            check_submodule
            sync_config
            log "Delegating 'test' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" test "$@")
            ;;

        import)
            check_submodule
            sync_config
            log "Delegating 'import' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" import "$@")
            ;;

        stop)
            check_submodule
            sync_config
            log "Delegating 'stop' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" stop "$@")
            ;;
        
        compose)
            check_submodule
            sync_all
            log "Delegating 'compose' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" compose "$@")
            ;;

        clientScopes)
            cmd_scopes
            ;;
            
        terraform)
            cmd_terraform "$@"
            ;;
            
        helm)
            cmd_helm "$@"
            ;;
            
        help|--help|-h)
            echo "Keycloak SSI Wrapper CLI"
            echo "Usage: ./keycloak-ssi.sh <command> [options]"
            echo ""
            echo "WRAPPER COMMANDS:"
            echo "  setup       Sync providers/configs and start Keycloak (submodule)"
            echo "  clientScopes      Configure client scopes only (direct API)"
            echo "  terraform   Run terraform commands in infrastructure/terraform"
            echo "  helm        Run helm commands in infrastructure/keycloak-chart"
            echo "  install     Install CLI to system PATH"
            echo "  uninstall   Remove CLI from system PATH"
            echo "  help        Show this help message"
            echo ""
            echo "SUBMODULE/DELEGATED COMMANDS:"
            echo "  config      Run full configuration scripts (submodule)"
            echo "  test        Run OID4VC tests (submodule)"
            echo "  import      Import ready realm configuration"
            echo "  stop        Stop Keycloak (submodule)"
            echo "  compose     Run docker compose commands (e.g., 'up -d', 'down -v')"
            echo ""
            ;;
            
        *)
             echo -e "${CLI_RED}[ERROR]${CLI_NC} Unknown command: $cmd" >&2
             echo "Run './keycloak-ssi.sh help' for usage information."
             exit 1
            ;;
    esac
}

main "$@"
