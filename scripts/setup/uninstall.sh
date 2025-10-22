#!/bin/bash

# Uninstall the Keycloak SSI CLI tool

set -e

echo "Uninstalling Keycloak SSI CLI..."

# Remove the symbolic link
if [ -L "/usr/local/bin/keycloak-ssi" ]; then
    sudo rm /usr/local/bin/keycloak-ssi
    echo "Symbolic link removed."
else
    echo "Symbolic link not found."
fi

echo "CLI tool uninstalled successfully."