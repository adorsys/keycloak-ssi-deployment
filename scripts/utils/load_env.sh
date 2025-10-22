#!/bin/bash

# Find the absolute path of the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# Go up two directories to the project root
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_ROOT/.env"

# Source common env variables
if [ -f "$ENV_FILE" ]; then
    set -a
    . "$ENV_FILE"
    set +a
else
    echo "Warning: .env file not found at $ENV_FILE"
fi

# Using local properties
if [ -n "$WORK_DIR" ] && [ -f "$WORK_DIR/../env/.env" ]; then
    echo "Using local properties from $WORK_DIR/../env/.env"
    . "$WORK_DIR/../env/.env"
    echo "$KC_START"
fi
