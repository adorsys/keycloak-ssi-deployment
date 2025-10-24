# Keycloak SSI CLI Cheat Sheet

```
      __ __                __            __      __________ ____
     / //_/__  __  _______/ /___  ____ _/ /__   / ___/ ___//  _/
    / ,< / _ \/ / / / ___/ / __ \/ __ `/ //_/   \__ \\__ \ / /
   / /| /  __/ /_/ / /__/ / /_/ / /_/ / ,<     ___/ /__/ // /
  /_/ |_\___/\__, /\___/_/\____/\__,_/_/|_|   /____/____/___/
            /____/
```

CLI Tool • Deployment • Configuration • Testing

---

## Usage

```bash
keycloak-ssi <command> [options]
```

---

## Commands

| Command                                    | Purpose                                        | Script Called                                                                                                             |
| ------------------------------------------ | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `install`                                  | Install CLI to system PATH                     | -                                                                                                                         |
| `uninstall`                                | Remove CLI from system PATH                    | -                                                                                                                         |
| `setup`                                    | Build and start Keycloak with OID4VCI          | `src/setup/0.start-kc-oid4vci.sh`                                                                                         |
| `config`                                   | Configure realm, keys, clients, and test users | `src/setup/1.oid4vci_test_deployment.sh`, `src/setup/2.configure_user_4_account_client.sh`                                |
| `test <preauth/authcode> <CredentialType>` | Test credential issuance flows                 | `src/credentials/request_credential.sh` (preauth), `src/credentials/request_credential_with_auth_code_flow.sh` (authcode) |
| `import`                                   | Import a pre-configured realm                  | `src/utils/import_kc_config.sh`                                                                                           |
| `stop`                                     | Stop running Keycloak                          | `src/utils/helper.sh` (stop_keycloak function)                                                                            |
| `help`                                     | Show this help message                         | -                                                                                                                         |

---

## Quick Start Example

```bash
# Install CLI
./keycloak-ssi install

# Setup Keycloak (first run)
keycloak-ssi setup

# Configure realm & test user
keycloak-ssi config

# Test credential flows
keycloak-ssi test preauth IdentityCredential
keycloak-ssi test authcode IdentityCredential

# Import a ready realm
keycloak-ssi import

# Stop Keycloak
keycloak-ssi stop

# Remove CLI
keycloak-ssi uninstall
```
