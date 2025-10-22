#!/bin/bash
#
# Infrastructure command for Keycloak SSI CLI
# Handles infrastructure management (Docker, Kubernetes, Terraform)
#

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../lib/common.sh"

show_help() {
    cat << EOF
Manage infrastructure components

USAGE:
    keycloak-ssi infrastructure <subcommand> [options]

SUBCOMMANDS:
    docker          Docker operations
    kubernetes      Kubernetes operations
    terraform       Terraform operations

EXAMPLES:
    keycloak-ssi infrastructure docker --build
    keycloak-ssi infrastructure docker --up
    keycloak-ssi infrastructure kubernetes --deploy
    keycloak-ssi infrastructure terraform --plan
    keycloak-ssi infrastructure terraform --apply
EOF
}

docker_operations() {
    local action="${1:-}"
    
    case "$action" in
        "--build")
            log_info "Building Docker images"
            cd "$PROJECT_ROOT/infrastructure/docker"
            docker build -f Dockerfile -t keycloak-ssi:latest .
            docker build -f Dockerfile.oid4vc-dev -t keycloak-ssi:oid4vc-dev .
            log_success "Docker images built successfully"
            ;;
        "--up")
            log_info "Starting Docker services"
            cd "$PROJECT_ROOT/infrastructure/docker"
            docker-compose up -d
            log_success "Docker services started"
            ;;
        "--down")
            log_info "Stopping Docker services"
            cd "$PROJECT_ROOT/infrastructure/docker"
            docker-compose down
            log_success "Docker services stopped"
            ;;
        "--logs")
            log_info "Showing Docker logs"
            cd "$PROJECT_ROOT/infrastructure/docker"
            docker-compose logs -f
            ;;
        *)
            log_error "Unknown Docker action: $action"
            echo "Available actions: --build, --up, --down, --logs"
            exit 1
            ;;
    esac
}

kubernetes_operations() {
    local action="${1:-}"
    
    case "$action" in
        "--deploy")
            log_info "Deploying to Kubernetes"
            kubectl apply -f "$PROJECT_ROOT/infrastructure/kubernetes/keycloak-chart/"
            log_success "Kubernetes deployment completed"
            ;;
        "--delete")
            log_info "Deleting Kubernetes resources"
            kubectl delete -f "$PROJECT_ROOT/infrastructure/kubernetes/keycloak-chart/"
            log_success "Kubernetes resources deleted"
            ;;
        "--status")
            log_info "Checking Kubernetes status"
            kubectl get pods -l app=keycloak
            kubectl get services -l app=keycloak
            ;;
        *)
            log_error "Unknown Kubernetes action: $action"
            echo "Available actions: --deploy, --delete, --status"
            exit 1
            ;;
    esac
}

terraform_operations() {
    local action="${1:-}"
    
    cd "$PROJECT_ROOT/infrastructure/terraform"
    
    case "$action" in
        "--init")
            log_info "Initializing Terraform"
            terraform init
            log_success "Terraform initialized"
            ;;
        "--plan")
            log_info "Creating Terraform plan"
            terraform plan
            ;;
        "--apply")
            log_info "Applying Terraform configuration"
            terraform apply -auto-approve
            log_success "Terraform applied successfully"
            ;;
        "--destroy")
            log_info "Destroying Terraform resources"
            terraform destroy -auto-approve
            log_success "Terraform resources destroyed"
            ;;
        "--output")
            log_info "Showing Terraform outputs"
            terraform output
            ;;
        *)
            log_error "Unknown Terraform action: $action"
            echo "Available actions: --init, --plan, --apply, --destroy, --output"
            exit 1
            ;;
    esac
}

main() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "docker")
            shift
            docker_operations "$@"
            ;;
        "kubernetes")
            shift
            kubernetes_operations "$@"
            ;;
        "terraform")
            shift
            terraform_operations "$@"
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
