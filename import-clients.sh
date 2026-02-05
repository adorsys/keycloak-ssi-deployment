#!/usr/bin/env bash
set -euo pipefail

# Import existing clients into Terraform state
cd "$(dirname "$0")/infrastructure/terraform"

echo "Fetching client IDs from Keycloak..."

TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | jq -r .access_token)

# Get client IDs
PUBLIC_ID=$(curl -k -s -X GET "https://localhost:8443/admin/realms/oid4vc-vci/clients" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.clientId=="oid4vc-demo-public") | .id')

API_ID=$(curl -k -s -X GET "https://localhost:8443/admin/realms/oid4vc-vci/clients" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.clientId=="openid4vc-rest-api") | .id')

echo "Importing oid4vc-demo-public (ID: $PUBLIC_ID)..."
terraform import 'module.clients.keycloak_openid_client.clients["oid4vc-demo-public"]' "oid4vc-vci/$PUBLIC_ID"

echo "Importing openid4vc-rest-api (ID: $API_ID)..."
terraform import 'module.clients.keycloak_openid_client.clients["openid4vc-rest-api"]' "oid4vc-vci/$API_ID"

echo "Import complete! You can now run: ./keycloak-ssi terraform apply"
