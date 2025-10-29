# Keycloak SSI CLI Guide

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

## Overview

The Keycloak SSI CLI simplifies the setup, configuration, and testing of Self-Sovereign Identity (SSI) environments built on Keycloak with OID4VCI (OpenID for Verifiable Credential Issuance).
It automates complex tasks such as realm setup, credential flow testing, and environment provisioning — all from a single, portable CLI interface.

---

## Prerequisites

Before using the CLI tool, ensure the following dependencies are installed on your system:

- **OpenSSL** — for SSL/TLS certificate generation and cryptographic operations
- **Keytool** — Java key and certificate management utility (included with JDK)
- **jq** — lightweight and flexible command-line JSON processor
- **figlet** — optional ASCII art generator for an enhanced CLI display
- **Java Version:**
  - A minimum of Java 17 is required.
  - For compatibility with the `keycloak-ssi import` feature (which uses the Keycloak config CLI), Java 21 is recommended.
    Make sure to set your JAVA_HOME environment variable accordingly:
    ```bash
    export JAVA_HOME=/usr/lib/jvm/jdk-21-oracle-x64/
    ```

---

## Installation

### Quick Installation

1. **Clone and install:**

   ```bash
   git clone https://github.com/adorsys/keycloak-ssi-deployment.git
   cd keycloak-ssi-deployment
   ./keycloak-ssi.sh install
   ```

2. **Verify installation:**
   ```bash
   keycloak-ssi help
   ```

The CLI tool follows the XDG Base Directory specification:

- **CLI Binary:** `~/.local/bin/keycloak-ssi`
- **Project Files:** `~/.local/share/keycloak-ssi-deployment` (symbolic link)

After installation, the CLI works from anywhere on your system without additional configuration.

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
# 1️⃣ Setup Keycloak (first run - may take 5–10 minutes)
keycloak-ssi setup

# 2️⃣ Configure the realm and create a test user
keycloak-ssi config

# or import a preconfigured realm
keycloak-ssi import

# 3️⃣ Test credential flows
keycloak-ssi test preauth IdentityCredential
keycloak-ssi test authcode IdentityCredential

# 4️⃣ Stop the Keycloak server
keycloak-ssi stop

# 5️⃣ Uninstall the CLI
keycloak-ssi uninstall
```
