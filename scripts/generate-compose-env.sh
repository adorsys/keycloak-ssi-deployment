#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Generate .env file for docker-compose from config.yaml
# -----------------------------------------------------------------------------
# This script reads configuration from config.yaml and generates a .env file
# that docker-compose can use. The .env file is automatically ignored by git.

set -euo pipefail
IFS=$'\n\t'

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source helper functions
source "$PROJECT_ROOT/src/utils/helper.sh"

# Initialize environment
WORK_DIR="$PROJECT_ROOT"
export WORK_DIR

# Load configuration from config.yaml
load_configuration

# Generate .env file for docker-compose
ENV_FILE="$PROJECT_ROOT/.env"

log "Generating .env file for docker-compose from config.yaml..."

# Write required docker-compose environment variables
cat > "$ENV_FILE" <<EOF
# -----------------------------------------------------------------------------
# Docker Compose Environment Variables
# -----------------------------------------------------------------------------
# This file is auto-generated from config.yaml
# DO NOT EDIT MANUALLY - Changes will be overwritten
# To customize values, edit config.yaml or config.override.yaml
# -----------------------------------------------------------------------------

# Database configuration
DATABASE_USERNAME=${DATABASE_USERNAME}
DATABASE_PASSWORD=${DATABASE_PASSWORD}
DATABASE_NAME=${DATABASE_NAME}
DATABASE_EXPOSED_PORT=${DATABASE_EXPOSED_PORT}

# Keycloak configuration
KEYCLOAK_HTTPS_PORT=${KEYCLOAK_HTTPS_PORT}
EOF

success "Generated .env file at $ENV_FILE"
log "You can now run 'docker compose up' without environment variable warnings"

