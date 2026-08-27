terraform {
  # Default to local backend for development.
  # Override with: terraform init -backend-config=backend-dev.hcl -reconfigure
  backend "local" {}
}

