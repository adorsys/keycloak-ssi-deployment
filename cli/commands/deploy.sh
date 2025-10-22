#!/bin/bash
#
# Deploy command for Keycloak SSI CLI
# Handles deployment and configuration of Keycloak
#

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../lib/common.sh"

show_help() {
    cat << EOF
Deploy and configure Keycloak

USAGE:
    keycloak-ssi deploy [options]

OPTIONS:
    --config CONFIG       Configuration profile (dev|release) (default: dev)
    --method METHOD       Deployment method (docker|kubernetes|terraform) (default: docker)
    --realm REALM         Realm name to create (default: oid4vc-vci)
    --wait                Wait for deployment to complete
    --help                Show this help message

EXAMPLES:
    keycloak-ssi deploy --config dev
    keycloak-ssi deploy --method docker --wait
    keycloak-ssi deploy --method kubernetes --config release
    keycloak-ssi deploy --method terraform --realm my-realm
EOF
}

deploy_docker() {
    local config="${1:-dev}"
    local wait="${2:-false}"
    
    log_info "Deploying Keycloak using Docker with config: $config"
    
    # Start Keycloak
    "$PROJECT_ROOT/scripts/setup/0.start-kc-oid4vci.sh"
    
    if [ "$wait" = "true" ]; then
        wait_for_keycloak
    fi
    
    # Configure Keycloak
    if [ "$config" = "dev" ]; then
        "$PROJECT_ROOT/scripts/deployment/1.oid4vci_test_deployment.sh"
    else
        "$PROJECT_ROOT/scripts/deployment/import_kc_config.sh"
    fi
    
    log_success "Docker deployment completed"
}

deploy_kubernetes() {
    local config="${1:-dev}"
    
    log_info "Deploying Keycloak using Kubernetes with config: $config"
    
    # Apply Kubernetes manifests
    kubectl apply -f "$PROJECT_ROOT/infrastructure/kubernetes/keycloak-chart/"
    
    log_success "Kubernetes deployment completed"
}

deploy_terraform() {
    local realm="${1:-oid4vc-vci}"
    
    log_info "Deploying Keycloak using Terraform with realm: $realm"
    
    cd "$PROJECT_ROOT/infrastructure/terraform"
    terraform init
    terraform plan -var="realm=$realm"
    terraform apply -var="realm=$realm" -auto-approve
    
    log_success "Terraform deployment completed"
}

main() {
    local config="dev"
    local method="docker"
    local realm="oid4vc-vci"
    local wait="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                config="$2"
                shift 2
                ;;
            --method)
                method="$2"
                shift 2
                ;;
            --realm)
                realm="$2"
                shift 2
                ;;
            --wait)
                wait="true"
                shift
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
    
    # Check dependencies
    check_dependencies
    load_env
    
    case "$method" in
        "docker")
            deploy_docker "$config" "$wait"
            ;;
        "kubernetes")
            deploy_kubernetes "$config"
            ;;
        "terraform")
            deploy_terraform "$realm"
            ;;
        *)
            log_error "Unknown deployment method: $method"
            exit 1
            ;;
    esac
}

main "$@"
