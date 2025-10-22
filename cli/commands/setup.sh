#!/bin/bash
#
# Setup command for Keycloak SSI CLI
# Handles initial setup of Keycloak with OID4VCI capabilities
#

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../lib/common.sh"

show_help() {
    cat << EOF
Setup Keycloak with OID4VCI capabilities

USAGE:
    keycloak-ssi setup [options]

OPTIONS:
    --version VERSION     Keycloak version to use (default: 26.0.7)
    --branch BRANCH       Git branch to use for custom builds (default: main)
    --ssl                 Enable SSL/TLS configuration
    --database TYPE       Database type (postgres|h2) (default: postgres)
    --help                Show this help message

EXAMPLES:
    keycloak-ssi setup --version 26.0.7
    keycloak-ssi setup --version 999.0.0-SNAPSHOT --branch datev/develop
    keycloak-ssi setup --ssl --database postgres
EOF
}

setup_keycloak() {
    local version="${1:-26.0.7}"
    local branch="${2:-main}"
    local ssl="${3:-false}"
    local database="${4:-postgres}"
    
    log_info "Setting up Keycloak version $version"
    
    # Check dependencies
    check_dependencies
    load_env
    
    # Create tools directory
    mkdir -p "$PROJECT_ROOT/tools"
    
    # Run setup script
    if [ "$version" = "999.0.0-SNAPSHOT" ]; then
        log_info "Building Keycloak from branch: $branch"
        KC_VERSION="$version" KC_TARGET_BRANCH="$branch" \
            "$PROJECT_ROOT/scripts/setup/setup-kc-oid4vci.sh"
    else
        log_info "Using Keycloak tarball version: $version"
        KC_VERSION="$version" \
            "$PROJECT_ROOT/scripts/setup/setup-kc-oid4vci.sh"
    fi
    
    # Generate certificates if SSL is enabled
    if [ "$ssl" = "true" ]; then
        log_info "Generating SSL certificates"
        "$PROJECT_ROOT/scripts/utils/generate-kc-certs.sh"
    fi
    
    log_success "Keycloak setup completed successfully"
}

main() {
    local version="26.0.7"
    local branch="main"
    local ssl="false"
    local database="postgres"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                version="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --ssl)
                ssl="true"
                shift
                ;;
            --database)
                database="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    setup_keycloak "$version" "$branch" "$ssl" "$database"
}

main "$@"
