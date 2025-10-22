#!/bin/bash
#
# Help command for Keycloak SSI CLI
# Shows comprehensive help information
#

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../lib/common.sh"

show_main_help() {
    cat << EOF
Keycloak SSI CLI Tool

A professional CLI tool for deploying and managing Keycloak with SSI capabilities.

USAGE:
    keycloak-ssi <command> [options]

COMMANDS:
    setup           Set up Keycloak with OID4VCI capabilities
    deploy          Deploy and configure Keycloak
    configure       Configure Keycloak realm and clients
    credentials     Manage verifiable credentials
    infrastructure  Manage infrastructure (Docker, Kubernetes, Terraform)
    help            Show this help message

EXAMPLES:
    # Setup Keycloak
    keycloak-ssi setup --version 26.0.7 --ssl
    
    # Deploy with Docker
    keycloak-ssi deploy --method docker --config dev --wait
    
    # Deploy with Kubernetes
    keycloak-ssi deploy --method kubernetes --config release
    
    # Request credentials
    keycloak-ssi credentials request --type identity --flow pre-authorized
    
    # Manage infrastructure
    keycloak-ssi infrastructure docker --build
    keycloak-ssi infrastructure kubernetes --deploy
    keycloak-ssi infrastructure terraform --apply

For detailed help on a specific command, run:
    keycloak-ssi <command> --help
EOF
}

show_command_help() {
    local command="$1"
    
    case "$command" in
        "setup")
            "$(dirname "$0")/setup.sh" --help
            ;;
        "deploy")
            "$(dirname "$0")/deploy.sh" --help
            ;;
        "credentials")
            "$(dirname "$0")/credentials.sh" --help
            ;;
        "infrastructure")
            "$(dirname "$0")/infrastructure.sh" --help
            ;;
        *)
            log_error "Unknown command: $command"
            show_main_help
            exit 1
            ;;
    esac
}

main() {
    local command="${1:-}"
    
    if [ -z "$command" ]; then
        show_main_help
    else
        show_command_help "$command"
    fi
}

main "$@"
