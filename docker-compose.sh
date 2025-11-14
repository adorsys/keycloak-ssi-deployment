#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Docker Compose Wrapper Script
# -----------------------------------------------------------------------------
# This script ensures the .env file exists before running docker-compose.
# The .env file is automatically generated from config.yaml if it doesn't exist.

set -euo pipefail
IFS=$'\n\t'

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Check if .env file exists
ENV_FILE="$PROJECT_ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo ".env file not found. Generating from config.yaml..."
    
    # Run the generate script
    if [[ -f "$PROJECT_ROOT/scripts/generate-compose-env.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/generate-compose-env.sh"
    else
        echo "Error: generate-compose-env.sh not found"
        echo "Please run: bash scripts/generate-compose-env.sh"
        exit 1
    fi
fi

# Detect docker-compose command
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    # Docker Compose v2 (plugin)
    DOCKER_COMPOSE_CMD=(docker compose)
elif command -v docker-compose &> /dev/null; then
    # Docker Compose v1 (standalone)
    DOCKER_COMPOSE_CMD=(docker-compose)
else
    echo "Error: Neither 'docker compose' (v2) nor 'docker-compose' (v1) is installed."
    exit 1
fi

# Execute docker-compose with all passed arguments
exec "${DOCKER_COMPOSE_CMD[@]}" "$@"

