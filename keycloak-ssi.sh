#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Keycloak SSI Deployment Wrapper
# =============================================================================
# Wraps the submodule CLI and adds infrastructure management (Terraform/Helm)
# =============================================================================

# Determine project root
determine_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Prefer running locally from the cloned repository
    if [[ -d "$script_dir/keycloak-oauth-sig" ]]; then
        echo "$script_dir"
        return
    fi
    # If installed, use XDG Base Directory
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local project_root="$xdg_data_home/keycloak-ssi-deployment"
    if [[ -d "$project_root/keycloak-oauth-sig" ]]; then
        echo "$project_root"
        return
    fi
    echo "Keycloak SSI project not found. Run from the project root or install with './keycloak-ssi.sh install'." >&2
    exit 1
}

PROJECT_ROOT="$(determine_project_root)"
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
success() { echo -e "${CLI_GREEN}[SUCCESS]${CLI_NC} $1"; }
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

        echo -e \"\${S_BLUE}[INFO]\${S_NC} Creating and assigning client scopes in realm '\$KEYCLOAK_REALM'...\"
        
        # Determine target clients for assignment
        TARGET_CLIENTS=(\"openid4vc-rest-api\" \"oid4vc-demo-public\")
        CLIENT_UUIDS=()
        for cid in \"\${TARGET_CLIENTS[@]}\"; do
            uuid=\$(\"\$KCADM\" get clients -r \"\$KEYCLOAK_REALM\" --query clientId=\"\$cid\" --fields id --format csv --noquotes)
            if [[ -n \"\$uuid\" ]]; then
                CLIENT_UUIDS+=(\"\$uuid\")
            fi
        done

        SCOPE_FILE=\"$PROJECT_ROOT/client-scopes.json\"
        if [[ -f \"\$SCOPE_FILE\" ]]; then
            # Inject Issuer DID and process each scope
            CLIENT_SCOPES_CONFIG=\$(jq --arg ISSUER_DID \"\$KEYCLOAK_ISSUER_DID\" 'map(.attributes[\"vc.issuer_did\"] = \$ISSUER_DID)' \"\$SCOPE_FILE\")
            
            echo \"\$CLIENT_SCOPES_CONFIG\" | jq -c '.[]' | while read -r scope; do
                SCOPE_NAME=\$(echo \"\$scope\" | jq -r .name)
                # Create scope
                if echo \"\$scope\" | \"\$KCADM\" create client-scopes -r \"\$KEYCLOAK_REALM\" -f - >/dev/null 2>&1; then
                    echo -e \"\${S_GREEN}[SUCCESS]\${S_NC} Client scope '\$SCOPE_NAME' created successfully.\"
                else
                    echo -e \"\${S_YELLOW}[INFO]\${S_NC} Client scope '\$SCOPE_NAME' already exists (skipping creation).\"
                fi

                # Get scope internal ID and assign to target clients
                SCOPE_UUID=\$(\"\$KCADM\" get client-scopes -r \"\$KEYCLOAK_REALM\" --fields id,name | jq -r --arg name \"\$SCOPE_NAME\" '.[] | select(.name == \$name) | .id')
                if [[ -n \"\$SCOPE_UUID\" ]]; then
                    for cuuid in \"\${CLIENT_UUIDS[@]}\"; do
                        \"\$KCADM\" update \"clients/\$cuuid/optional-client-scopes/\$SCOPE_UUID\" -r \"\$KEYCLOAK_REALM\" >/dev/null 2>&1
                    done
                    echo -e \"\${S_BLUE}[INFO]\${S_NC} Client scope '\$SCOPE_NAME' assigned to target clients.\"
                fi
            done
        else
            echo -e \"\${S_RED}[ERROR]\${S_NC} Scope configuration file not found at \$SCOPE_FILE\"
            exit 1
        fi
    ")
}

cmd_terraform() {
    local tf_dir="$PROJECT_ROOT/infrastructure/terraform"
    log "Delegating to Terraform in $tf_dir..."
    
    if [[ ! -d "$tf_dir" ]]; then
        error "Terraform directory not found at $tf_dir"
    fi

    # Load configuration to pass as environment variables to Terraform
    (
        cd "$TEST_DEPLOYMENT_DIR"
        source src/utils/helper.sh
        setup_environment
        
        # Map Keycloak config to TF_VAR equivalents
        export TF_VAR_keycloak_url="$KEYCLOAK_ADMIN_ADDR"
        export TF_VAR_admin_password="$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"
        
        cd "$tf_dir"
        terraform "$@"
    )
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

cmd_install() {
    log "Installing keycloak-ssi CLI to system PATH..."

    # Determine install directory
    local install_dir="/usr/local/bin"
    if [[ ! -w "$install_dir" ]]; then
        install_dir="$HOME/.local/bin"
        mkdir -p "$install_dir"
    fi

    local install_path="$install_dir/keycloak-ssi"

    # Install project files to XDG Base Directory using symbolic link
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local project_install_dir="$xdg_data_home/keycloak-ssi-deployment"
    
    log "Installing project files to $project_install_dir..."
    mkdir -p "$xdg_data_home"
    if [[ -e "$project_install_dir" ]]; then
        rm -rf "$project_install_dir"
    fi
    ln -s "$PROJECT_ROOT" "$project_install_dir" || error "Failed to create symbolic link"

    # Install CLI script
    rm -f "$install_path"
    cp "$PROJECT_ROOT/keycloak-ssi.sh" "$install_path"
    chmod +x "$install_path"

    # Check if PATH includes install directory
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        warn "Please add $install_dir to your PATH:"
        echo "  export PATH=\"\$PATH:$install_dir\""
    fi

    success "CLI installed to $install_path"
}

cmd_uninstall() {
    log "Uninstalling keycloak-ssi CLI..."
    local locations=("/usr/local/bin/keycloak-ssi" "$HOME/.local/bin/keycloak-ssi")
    for location in "${locations[@]}"; do
        if [[ -f "$location" ]]; then
            rm -f "$location"
            success "Removed $location"
        fi
    done
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local project_install_dir="$xdg_data_home/keycloak-ssi-deployment"
    if [[ -e "$project_install_dir" ]]; then
        rm -f "$project_install_dir"
        success "Removed project files from $project_install_dir"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    if ! command -v figlet >/dev/null 2>&1; then
        warn "figlet not found, using fallback (no banner rendering)"

        figlet() {
            local last_arg=""
            for arg in "$@"; do
                [[ "$arg" != -* ]] && last_arg="$arg"
            done
            [[ -n "$last_arg" ]] && echo "$last_arg"
        }
        export -f figlet
    fi

    case "$cmd" in
        setup)
            check_submodule
            sync_all
            
            # Handle --clean flag
            local setup_args=()
            local clean_start=false
            for arg in "$@"; do
                if [[ "$arg" == "--clean" ]]; then
                    clean_start=true
                else
                    setup_args+=("$arg")
                fi
            done

            if [[ "$clean_start" == "true" ]]; then
                log "Clean start requested. Wiping database and existing volumes..."
                (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" compose down -v)
            fi

            log "Delegating 'setup' to submodule CLI..."
            (cd "$TEST_DEPLOYMENT_DIR" && "$SUBMODULE_CLI" setup "${setup_args[@]}")
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

        addClientScopes)
            cmd_scopes
            ;;
            
        terraform)
            cmd_terraform "$@"
            ;;
            
        helm)
            cmd_helm "$@"
            ;;

        install)
            cmd_install
            ;;

        uninstall)
            cmd_uninstall
            ;;
            
        help|--help|-h)
            echo "Keycloak SSI Wrapper CLI"
            echo "Usage: ./keycloak-ssi.sh <command> [options]"
            echo ""
            echo "WRAPPER COMMANDS:"
            echo "  setup       Sync providers/configs and start Keycloak (submodule)"
            echo "  addClientScopes     Configure client scopes only (direct API)"
            echo "  terraform   Run terraform commands (auto-manages credentials)"
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
