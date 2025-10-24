# Keycloak SSI CLI Guide

A simple command-line tool for deploying and testing Keycloak with OID4VCI (OpenID for Verifiable Credential Issuance) features.

## Installation

```bash
# Install CLI to system PATH
./keycloak-ssi install

# Verify installation
keycloak-ssi help
```

## Commands

### `keycloak-ssi setup`

**Purpose**: Build and start Keycloak with OID4VCI features  
**Scripts called**: `src/setup/0.start-kc-oid4vci.sh`  
**Time**: 5-10 minutes (first run)  
**What it does**:

- Downloads/builds Keycloak from source
- Generates certificates and keystore
- Starts Keycloak server on port 8443

### `keycloak-ssi config`

**Purpose**: Configure realm, clients, key providers and users
**Scripts called**:

- `src/setup/1.oid4vci_test_deployment.sh`
- `src/setup/2.configure_user_4_account_client.sh`  
  **What it does**:
- Creates test realm with OID4VCI configuration
- Sets up key providers (EC, RSA)
- Creates test client and user (francis/password)
- Configures credential types

### `keycloak-ssi test <flow> <credential>`

**Purpose**: Test credential issuance flows  
**Flows**: `preauth` or `authcode`  
**Credentials**: `IdentityCredential`, `SteuerberaterCredential`, and `KMACredential`.  
**Scripts called**:

- `preauth`: `src/credentials/request_credential.sh`
- `authcode`: `src/credentials/request_credential_with_auth_code_flow.sh`  
  **What it does**:
- Tests pre-authorized code flow (simpler)
- Tests authorization code + PKCE flow (OAuth2 standard)

### `keycloak-ssi import`

**Purpose**: Import ready realm configuration  
**Scripts called**: `src/utils/import_kc_config.sh`  
**What it does**: Imports pre-configured realm from JSON file

### `keycloak-ssi stop`

**Purpose**: Stop running Keycloak  
**Scripts called**: `src/utils/helper.sh` (stop_keycloak function)  
**What it does**: Gracefully stops Keycloak server

## Quick Start

```bash
# 1. Setup Keycloak (first time only)
keycloak-ssi setup

# 2. Configure realm and users
keycloak-ssi config

# 3. Test credential flows
keycloak-ssi test preauth IdentityCredential
keycloak-ssi test authcode IdentityCredential

# 4. Stop when done
keycloak-ssi stop
```

## Environment

The CLI automatically loads environment variables from:

- `load_env.sh` - Main configuration
- `src/utils/helper.sh` - Helper functions

Key variables:

- `KEYCLOAK_ADMIN_ADDR`: https://localhost:8443
- `KEYCLOAK_URL`: https://localhost:8443
- `USER_FRANCIS_PASSWORD`: Test user password

## Troubleshooting

**"Keycloak is not running"**: Run `keycloak-ssi setup` first  
**"command not found"**: Run `./keycloak-ssi install` and reload shell  
**Build fails**: Check Java/Maven installation  
**Port conflicts**: Ensure port 8443 is available

## Script Architecture

```
src/
├── setup/
│   ├── 0.start-kc-oid4vci.sh                     # Build & start Keycloak
│   ├── 1.oid4vci_test_deployment.sh              # Configure realm & keys
│   └── 2.configure_user_4_account_client.sh      # Create users & clients
├── credentials/
│   ├── request_credential.sh                     # Pre-authorized flow
│   └── request_credential_with_auth_code_flow.sh # Auth code flow
└── utils/
    ├── helper.sh                                 # Common functions
    └── import_kc_config.sh                       # Import configuration
```

Each command calls the appropriate scripts in sequence to achieve the desired functionality.

