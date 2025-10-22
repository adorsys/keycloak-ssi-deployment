#!/bin/bash
#
# Credentials command for Keycloak SSI CLI
# Handles verifiable credential operations
#

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../lib/common.sh"

show_help() {
    cat << EOF
Manage verifiable credentials

USAGE:
    keycloak-ssi credentials <subcommand> [options]

SUBCOMMANDS:
    request         Request verifiable credentials
    list            List available credential types
    validate        Validate a credential

EXAMPLES:
    keycloak-ssi credentials request --type identity
    keycloak-ssi credentials request --type kma --flow auth-code
    keycloak-ssi credentials list
    keycloak-ssi credentials validate --credential-file credential.json
EOF
}

request_credential() {
    local type="${1:-identity}"
    local flow="${2:-pre-authorized}"
    
    log_info "Requesting credential type: $type with flow: $flow"
    
    # Map CLI types to actual credential types
    case "$type" in
        "identity")
            local credential_type="IdentityCredential"
            ;;
        "kma")
            local credential_type="KMACredential"
            ;;
        "steuerberater")
            local credential_type="SteuerberaterCredential"
            ;;
        *)
            log_error "Unknown credential type: $type"
            exit 1
            ;;
    esac
    
    if [ "$flow" = "pre-authorized" ]; then
        "$PROJECT_ROOT/scripts/credentials/retrieve_credential.sh" "$credential_type"
    else
        "$PROJECT_ROOT/scripts/credentials/3.request_credentials_with_auth_code_flow.sh"
    fi
    
    log_success "Credential request completed"
}

list_credentials() {
    log_info "Available credential types:"
    echo "  - identity: Identity Credential"
    echo "  - kma: KMA Credential"
    echo "  - steuerberater: Steuerberater Credential"
}

validate_credential() {
    local credential_file="$1"
    
    if [ ! -f "$credential_file" ]; then
        log_error "Credential file not found: $credential_file"
        exit 1
    fi
    
    log_info "Validating credential: $credential_file"
    
    # Basic JSON validation
    if jq empty "$credential_file" 2>/dev/null; then
        log_success "Credential file is valid JSON"
    else
        log_error "Credential file is not valid JSON"
        exit 1
    fi
}

main() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "request")
            shift
            local type="identity"
            local flow="pre-authorized"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --type)
                        type="$2"
                        shift 2
                        ;;
                    --flow)
                        flow="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_help
                        exit 1
                        ;;
                esac
            done
            
            request_credential "$type" "$flow"
            ;;
        "list")
            list_credentials
            ;;
        "validate")
            shift
            local credential_file=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --credential-file)
                        credential_file="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_help
                        exit 1
                        ;;
                esac
            done
            
            if [ -z "$credential_file" ]; then
                log_error "Credential file is required"
                exit 1
            fi
            
            validate_credential "$credential_file"
            ;;
        "")
            show_help
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
