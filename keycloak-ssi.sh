#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Keycloak SSI CLI Tool
# =============================================================================
# Professional CLI for Keycloak SSI deployment and testing
# 
# Commands:
#   setup    - Build and start Keycloak with OID4VCI features
#   config   - Configure realm, key providers, clients, and users
#   test     - Test credential flows (preauth | authcode)
#   import   - Import ready realm configuration
# =============================================================================

# Colors for output (avoid conflicts with helper.sh)
# Use real ANSI escapes only when stdout is a TTY
if [ -t 1 ]; then
  CLI_RED="$(printf '\033[0;31m')"
  CLI_GREEN="$(printf '\033[0;32m')"
  CLI_YELLOW="$(printf '\033[1;33m')"
  CLI_CYAN="$(printf '\033[0;36m')"
  CLI_BLUE="$(printf '\033[1;34m')"
  CLI_NC="$(printf '\033[0m')"
else
  CLI_RED=""; CLI_GREEN=""; CLI_YELLOW=""; CLI_CYAN=""; CLI_BLUE=""; CLI_NC="";
fi

# =============================================================================
# Project Root Detection
# Uses XDG Base Directory specification for clean, professional CLI behavior
# =============================================================================

# Determine project root using XDG Base Directory specification
determine_project_root() {
    local project_root=""
    
    # Special case: if running install command, use script location
    if [[ "${1:-}" == "install" ]]; then
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ -f "$script_dir/src/utils/helper.sh" && -f "$script_dir/load_env.sh" ]]; then
            echo "$script_dir"
            return
        fi
    fi
    
    # Normal case: use XDG Base Directory
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    project_root="$xdg_data_home/keycloak-ssi-deployment"
    
    # Validate project files exist
    if [[ -f "$project_root/src/utils/helper.sh" && -f "$project_root/load_env.sh" ]]; then
        echo "$project_root"
    else
        echo "Keycloak SSI project not found. Please install the CLI:" >&2
        echo "1. Run: ./keycloak-ssi.sh install" >&2
        exit 1
    fi
}

# Set project root
WORK_DIR="$(determine_project_root "${1:-}")"

# Export WORK_DIR so helper functions can use it
export WORK_DIR

# Load helper functions
source "$WORK_DIR/src/utils/helper.sh"

# =============================================================================
# CLI Functions
# =============================================================================

show_help() {
    printf "%s\n" \
"${CLI_CYAN}USAGE${CLI_NC}" \
"  keycloak-ssi <command> [options]" \
"" \
"${CLI_CYAN}COMMANDS${CLI_NC}" \
"  ${CLI_GREEN}setup${CLI_NC}                       Build and start Keycloak with OID4VCI features" \
"  ${CLI_GREEN}config${CLI_NC}                      Configure realm, key providers, clients, and users" \
"  ${CLI_GREEN}test${CLI_NC}                        <preauth|authcode> <CredentialType>   Test credential flows" \
"  ${CLI_GREEN}import${CLI_NC}                      Import ready realm configuration" \
"  ${CLI_GREEN}stop${CLI_NC}                        Stop running Keycloak instance" \
"  ${CLI_GREEN}install${CLI_NC}                     Install CLI to system PATH" \
"  ${CLI_GREEN}uninstall${CLI_NC}                   Remove CLI from system PATH" \
"  ${CLI_GREEN}help${CLI_NC}                        Show this help message" \
"" \
"${CLI_CYAN}EXAMPLES${CLI_NC}" \
"  keycloak-ssi install" \
"  keycloak-ssi setup" \
"  keycloak-ssi config" \
"  keycloak-ssi test preauth IdentityCredential" \
"  keycloak-ssi test authcode IdentityCredential" \
"  keycloak-ssi import" \
"  keycloak-ssi stop" \
"  keycloak-ssi uninstall" \
"" \
"${CLI_YELLOW}Note:${CLI_NC} 'setup' may take 5-10 minutes on first run."
}

show_banner() {
    echo
    # Use figlet if available, fallback to simple text
    if command -v figlet >/dev/null 2>&1; then
        figlet -f slant "Keycloak SSI" | sed 's/^/  /'
        echo ""
        echo "${CLI_CYAN}  CLI Tool • Deployment • Configuration • Testing${CLI_NC}"
    else
        echo "${CLI_CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${CLI_NC}"
        echo "${CLI_CYAN}║                              Keycloak SSI CLI Tool                            ║${CLI_NC}"
        echo "${CLI_CYAN}║                     Deployment • Configuration • Testing                      ║${CLI_NC}"
        echo "${CLI_CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${CLI_NC}"
    fi
    echo
}

log() {
    echo -e "${CLI_BLUE}[INFO]${CLI_NC} $1"
}

success() {
    echo -e "${CLI_GREEN}[SUCCESS]${CLI_NC} $1"
}

warn() {
    echo -e "${CLI_YELLOW}[WARN]${CLI_NC} $1"
}

error() {
    echo -e "${CLI_RED}[ERROR]${CLI_NC} $1"
    exit 1
}

# =============================================================================
# Command Functions
# =============================================================================

cmd_setup() {
    log "Setting up Keycloak with OID4VCI features..."
    log "This may take 5-10 minutes for first-time build..."
    
    # Run setup script in background to avoid signal issues
    log "Starting Keycloak setup..."
    WORK_DIR="$WORK_DIR" "$WORK_DIR/src/setup/0.start-kc-oid4vci.sh" &
    local setup_pid=$!
    
    # Wait for setup to complete
    log "Waiting for setup to complete..."
    wait $setup_pid
    local setup_exit_code=$?
    
    if [[ $setup_exit_code -ne 0 ]]; then
        error "Setup failed with exit code $setup_exit_code"
    fi
    
    # Wait for Keycloak to be ready
    log "Waiting for Keycloak to be ready..."
    for i in {1..120}; do
        if curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/master" >/dev/null 2>&1; then
            success "Keycloak is ready and running"
            success "Admin Console: $KEYCLOAK_ADMIN_ADDR"
            return 0
        fi
        if [[ $i -eq 120 ]]; then
            error "Keycloak failed to start within 2 minutes"
        fi
        echo -n "."
        sleep 1
    done
}

cmd_config() {
    log "Configuring realm, key providers, clients, and users..."
    
    # Check if Keycloak is running
    if ! curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/master" >/dev/null 2>&1; then
        error "Keycloak is not running. Run 'keycloak-ssi setup' first."
    fi
    
    # Run both configuration scripts
    log "Running OID4VCI test deployment configuration..."
    "$WORK_DIR/src/setup/1.oid4vci_test_deployment.sh"
    
    log "Configuring user and account client..."
    "$WORK_DIR/src/setup/2.configure_user_4_account_client.sh"
    
    success "Configuration completed"
    success "Test User: francis / $USER_FRANCIS_PASSWORD"
}

cmd_test() {
    local flow="${1:-}"
    local credential_type="${2:-}"
    
    if [[ -z "$flow" || -z "$credential_type" ]]; then
        error "Usage: keycloak-ssi test <preauth|authcode> <CredentialType>"
    fi
    
    # Check if Keycloak is running
    if ! curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/master" >/dev/null 2>&1; then
        error "❌ Keycloak is not running. Run 'keycloak-ssi setup' first."
    fi
    
    case "$flow" in
        "preauth")
            log "Testing Pre-authorized Code Flow..."
            log "Credential: $credential_type"
            "$WORK_DIR/src/credentials/request_credential.sh" "$credential_type"
            ;;
        "authcode")
            log "Testing Authorization Code + PKCE Flow..."
            log "Credential: $credential_type"
            "$WORK_DIR/src/credentials/request_credential_with_auth_code_flow.sh" "$credential_type"
            ;;
        *)
            error "Invalid flow. Use 'preauth' or 'authcode'"
            ;;
    esac
    
    success "Test completed"
}

cmd_import() {
    log "📥 Importing ready realm configuration..."
    
    # Check if Keycloak is running
    if ! curl -k -s "$KEYCLOAK_ADMIN_ADDR/realms/master" >/dev/null 2>&1; then
        error "❌ Keycloak is not running. Run 'keycloak-ssi setup' first."
    fi
    
    # Run import script
    "$WORK_DIR/src/utils/import_kc_config.sh"
    
    success "Realm configuration imported"
}

cmd_stop() {
    log "Stopping Keycloak if running..."
    stop_keycloak
    success "Stop command completed"
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

    # Check if already installed
    if command -v keycloak-ssi >/dev/null 2>&1; then
        local existing_path
        existing_path="$(command -v keycloak-ssi)"
        if [[ "$existing_path" == "$install_path" ]]; then
            success "CLI is already installed at $existing_path"
            return 0
        else
            warn "CLI is installed at $existing_path, reinstalling to $install_path..."
        fi
    fi

    # Install project files to XDG Base Directory using symbolic link
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local project_install_dir="$xdg_data_home/keycloak-ssi-deployment"
    
    log "Installing project files to $project_install_dir..."
    
    # Ensure the parent directory exists for the project installation
    mkdir -p "$xdg_data_home"

    # Remove existing installation (whether symlink or directory)
    if [[ -e "$project_install_dir" ]]; then
        rm -rf "$project_install_dir"
    fi
    
    # Create symbolic link to project directory
    ln -s "$WORK_DIR" "$project_install_dir" || error "Failed to create symbolic link"

    # Install CLI script
    rm -f "$install_path"
    cp "$WORK_DIR/keycloak-ssi.sh" "$install_path"
    chmod +x "$install_path"

    # Check if PATH includes install directory
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        warn "Please add $install_dir to your PATH:"
        echo "  export PATH=\"\$PATH:$install_dir\""
        echo "  # Add to ~/.bashrc or ~/.zshrc for persistence"
    fi

    success "CLI installed to $install_path"
    success "Project files installed to $project_install_dir"
    success "You can now run 'keycloak-ssi' from anywhere"
}

cmd_uninstall() {
    log "Uninstalling keycloak-ssi CLI..."
    
    # Try common locations
    local locations=("/usr/local/bin/keycloak-ssi" "$HOME/.local/bin/keycloak-ssi")
    local removed=false
    
    for location in "${locations[@]}"; do
        if [[ -f "$location" ]]; then
            rm -f "$location"
            success "Removed $location"
            removed=true
        fi
    done
    
    # Remove project files from XDG Base Directory (symlink or directory)
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local project_install_dir="$xdg_data_home/keycloak-ssi-deployment"
    
    if [[ -e "$project_install_dir" ]]; then
        rm -f "$project_install_dir"  # Works for both symlinks and directories
        success "Removed project files from $project_install_dir"
        removed=true
    fi
    
    if [[ "$removed" == "false" ]]; then
        warn "No keycloak-ssi installation found in common locations"
    else
        success "CLI uninstalled successfully"
    fi
}

# =============================================================================
# Main CLI Logic
# =============================================================================

main() {
    # Check dependencies first
    check_dependencies

    # Show banner
    show_banner
    
    # Check if we're in the right directory
    if [[ ! -f "$WORK_DIR/src/utils/helper.sh" ]]; then
        error "❌ Please run this script from the project root directory"
    fi
    
    # Load environment variables
    if [[ -f "$WORK_DIR/load_env.sh" ]]; then
        source "$WORK_DIR/load_env.sh"
    fi
    
    # Parse command
    case "${1:-help}" in
        "setup")
            cmd_setup
            ;;
        "config")
            cmd_config
            ;;
        "test")
            cmd_test "${2:-}" "${3:-}"
            ;;
        "import")
            cmd_import
            ;;
        "stop")
            cmd_stop
            ;;
        "install")
            cmd_install
            ;;
        "uninstall")
            cmd_uninstall
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            echo -e "${CLI_RED}[ERROR]${CLI_NC} Unknown command: $1" >&2
            echo "Run 'keycloak-ssi help' for usage information."
            # exit 1
            ;;
    esac
}

# Run main function
main "$@"

