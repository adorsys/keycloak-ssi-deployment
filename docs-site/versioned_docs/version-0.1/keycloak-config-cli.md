# Keycloak Configuration CLI

The `keycloak-config-cli` is a powerful command-line interface tool used to manage Keycloak realms, clients, users, and other configurations. It allows for declarative configuration of Keycloak instances, making it ideal for automated deployments and consistent environment setups.

## Key Features

*   **Declarative Configuration**: Define your Keycloak configuration in YAML or JSON files and apply them using the CLI.
*   **Idempotent Operations**: Apply configurations multiple times without unintended side effects.
*   **Version Control Friendly**: Store your Keycloak configuration in version control systems (e.g., Git) for better management and auditing.
*   **Environment Agnostic**: Easily apply the same configuration across different environments (development, staging, production).

## Usage

The `keycloak-config-cli` is typically used within a Dockerized environment or as a standalone executable. In this project, it's integrated into the `setup-kc-oid4vci.sh` script to automate the initial Keycloak setup.

### Example Configuration (YAML)

```yaml
realm:
  realm: myrealm
  enabled: true
  clients:
    - clientId: my-client
      enabled: true
      publicClient: true
      redirectUris:
        - "http://localhost:8080/*"
      webOrigins:
        - "http://localhost:8080"
```

### Applying Configuration

To apply a configuration file, you would typically run a command similar to this:

```bash
keycloak-config-cli --import config.yaml
```

In our setup, the `src/deployment/setup-kc-oid4vci.sh` script handles the execution of `keycloak-config-cli` with the appropriate configuration files located in the `config/` directory.

## Configuration Files

The project uses the following configuration files with `keycloak-config-cli`:

*   [`config/keycloak-config-dev.json`](https://github.com/adorsys/keycloak-ssi-deployment/tree/main/config/keycloak-config-dev.json): Development environment configuration.
*   [`config/keycloak-config-release.json`](https://github.com/adorsys/keycloak-ssi-deployment/tree/main/config/keycloak-config-release.json): Release environment configuration.

These files define the realm, clients, roles, and other settings for the Keycloak instance.