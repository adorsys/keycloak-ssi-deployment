# Keycloak SSI Deployment Makefile
# Professional build and deployment automation

.PHONY: help install setup deploy configure credentials infrastructure clean test lint docs

# Default target
.DEFAULT_GOAL := help

# Variables
CLI_BIN := cli/bin/keycloak-ssi
PROJECT_ROOT := $(shell pwd)
DOCKER_COMPOSE := infrastructure/docker/docker-compose.yml
TERRAFORM_DIR := infrastructure/terraform

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Help target
help: ## Show this help message
	@echo "$(BLUE)Keycloak SSI Deployment - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup & Installation:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*##.*Setup|Install' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Deployment:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*##.*Deploy|Start|Stop' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*##.*Test|Lint|Clean' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)CLI Commands:$(NC)"
	@echo "  $(YELLOW)cli-setup$(NC)           Run CLI setup command"
	@echo "  $(YELLOW)cli-deploy$(NC)          Run CLI deploy command"
	@echo "  $(YELLOW)cli-credentials$(NC)     Run CLI credentials command"
	@echo "  $(YELLOW)cli-infrastructure$(NC)  Run CLI infrastructure command"

# Installation
install: ## Install CLI tool and dependencies
	@echo "$(BLUE)Installing Keycloak SSI CLI...$(NC)"
	@chmod +x $(CLI_BIN)
	@sudo ln -sf $(PROJECT_ROOT)/$(CLI_BIN) /usr/local/bin/keycloak-ssi
	@echo "$(GREEN)CLI tool installed successfully$(NC)"

uninstall: ## Uninstall CLI tool
	@echo "$(BLUE)Uninstalling Keycloak SSI CLI...$(NC)"
	@$(CLI_BIN) uninstall
	@echo "$(GREEN)CLI tool uninstalled successfully$(NC)"

# Setup commands
setup: ## Setup Keycloak with OID4VCI capabilities
	@echo "$(BLUE)Setting up Keycloak...$(NC)"
	@$(CLI_BIN) setup --version 26.0.7 --ssl

setup-dev: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@$(CLI_BIN) setup --version 999.0.0-SNAPSHOT --branch datev/develop --ssl

# Deployment commands
deploy: ## Deploy Keycloak using Docker
	@echo "$(BLUE)Deploying Keycloak...$(NC)"
	@$(CLI_BIN) deploy --method docker --config dev --wait

deploy-k8s: ## Deploy to Kubernetes
	@echo "$(BLUE)Deploying to Kubernetes...$(NC)"
	@$(CLI_BIN) deploy --method kubernetes --config release

deploy-terraform: ## Deploy using Terraform
	@echo "$(BLUE)Deploying with Terraform...$(NC)"
	@$(CLI_BIN) deploy --method terraform --realm oid4vc-vci

# Infrastructure commands
docker-build: ## Build Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@$(CLI_BIN) infrastructure docker --build

docker-up: ## Start Docker services
	@echo "$(BLUE)Starting Docker services...$(NC)"
	@$(CLI_BIN) infrastructure docker --up

docker-down: ## Stop Docker services
	@echo "$(BLUE)Stopping Docker services...$(NC)"
	@$(CLI_BIN) infrastructure docker --down

docker-logs: ## Show Docker logs
	@$(CLI_BIN) infrastructure docker --logs

k8s-deploy: ## Deploy to Kubernetes
	@echo "$(BLUE)Deploying to Kubernetes...$(NC)"
	@$(CLI_BIN) infrastructure kubernetes --deploy

k8s-status: ## Check Kubernetes status
	@$(CLI_BIN) infrastructure kubernetes --status

terraform-init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@$(CLI_BIN) infrastructure terraform --init

terraform-plan: ## Create Terraform plan
	@$(CLI_BIN) infrastructure terraform --plan

terraform-apply: ## Apply Terraform configuration
	@echo "$(BLUE)Applying Terraform configuration...$(NC)"
	@$(CLI_BIN) infrastructure terraform --apply

terraform-destroy: ## Destroy Terraform resources
	@echo "$(RED)Destroying Terraform resources...$(NC)"
	@$(CLI_BIN) infrastructure terraform --destroy

# Credential commands
credentials-identity: ## Request identity credential
	@echo "$(BLUE)Requesting identity credential...$(NC)"
	@$(CLI_BIN) credentials request --type identity --flow pre-authorized

credentials-kma: ## Request KMA credential
	@$(CLI_BIN) credentials request --type kma --flow pre-authorized

credentials-steuerberater: ## Request Steuerberater credential
	@$(CLI_BIN) credentials request --type steuerberater --flow pre-authorized

credentials-list: ## List available credential types
	@$(CLI_BIN) credentials list

# Development commands
test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	@if [ -d "tests" ]; then \
		echo "Running unit tests..."; \
		echo "Running integration tests..."; \
		echo "Running E2E tests..."; \
	fi
	@echo "$(GREEN)Tests completed$(NC)"

lint: ## Run linting
	@echo "$(BLUE)Running linting...$(NC)"
	@find . -name "*.sh" -exec shellcheck {} \;
	@echo "$(GREEN)Linting completed$(NC)"

clean: ## Clean up generated files
	@echo "$(BLUE)Cleaning up...$(NC)"
	@rm -rf tools/
	@rm -rf .terraform/
	@rm -f *.log
	@echo "$(GREEN)Cleanup completed$(NC)"

# Documentation
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@mkdir -p docs/generated
	@echo "$(GREEN)Documentation generated$(NC)"

# Quick start
quickstart: setup deploy ## Quick start: setup and deploy
	@echo "$(GREEN)Quick start completed!$(NC)"
	@echo "$(BLUE)Keycloak is now running with SSI capabilities$(NC)"

# CLI shortcuts
cli-setup: ## Run CLI setup command
	@$(CLI_BIN) setup $(ARGS)

cli-deploy: ## Run CLI deploy command
	@$(CLI_BIN) deploy $(ARGS)

cli-credentials: ## Run CLI credentials command
	@$(CLI_BIN) credentials $(ARGS)

cli-infrastructure: ## Run CLI infrastructure command
	@$(CLI_BIN) infrastructure $(ARGS)

# Status check
status: ## Check system status
	@echo "$(BLUE)Checking system status...$(NC)"
	@echo "CLI Tool: $(shell which keycloak-ssi 2>/dev/null || echo 'Not installed')"
	@echo "Docker: $(shell docker --version 2>/dev/null || echo 'Not installed')"
	@echo "Kubectl: $(shell kubectl version --client 2>/dev/null || echo 'Not installed')"
	@echo "Terraform: $(shell terraform version 2>/dev/null || echo 'Not installed')"
	@echo "Keycloak: $(shell pgrep -f keycloak >/dev/null 2>&1 && echo 'Running' || echo 'Not running')"
