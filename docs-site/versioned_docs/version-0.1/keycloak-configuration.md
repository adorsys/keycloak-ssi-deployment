# Keycloak Configuration

The Keycloak SSI Deployment leverages both direct JSON configuration files and Terraform for managing Keycloak resources. This approach provides flexibility for initial setup and robust, version-controlled management of more complex configurations.

## Initial Configuration with JSON

Upon startup, Keycloak can be pre-configured using JSON files. The project includes files like [config/keycloak-config-dev.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/keycloak-config-dev.json) and [config/keycloak-config-release.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/keycloak-config-release.json) which define the initial realm, clients, users, and other settings.

The [config/import_kc_config.sh](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/import_kc_config.sh) script is responsible for importing these configurations into the running Keycloak instance. This allows for a quick and consistent setup of the basic Keycloak environment.

## Managing Configuration with Terraform

For more advanced and maintainable configurations, the project utilizes Terraform. The [config/terraform](https://github.com/adorsys/keycloak-ssi-deployment/tree/main/config/terraform) directory contains all the necessary Terraform files to manage Keycloak resources programmatically.

**Key Terraform Components:**

*   **`main.tf`**: The main Terraform configuration file that orchestrates the deployment of Keycloak resources.
*   **`provider.tf`**: Defines the Terraform provider for Keycloak.
*   **`variables.tf`**: Contains variable definitions used across the Terraform configurations, allowing for flexible and environment-specific deployments.
*   **`jsons/`**: This subdirectory holds JSON files that define specific Keycloak entities, which are then referenced by the Terraform configurations.
    *   `identity_providers/`: JSON definitions for identity providers, such as [config/terraform/jsons/identity_providers/saml-idp-config.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/identity_providers/saml-idp-config.json).
    *   `keys/`: JSON definitions for various keys, including [config/terraform/jsons/keys/ecdsa-issuer-key.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/keys/ecdsa-issuer-key.json), [config/terraform/jsons/keys/rsa-encryption-key.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/keys/rsa-encryption-key.json), and [config/terraform/jsons/keys/rsa-issuer-key.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/keys/rsa-issuer-key.json).
    *   `scopes/`: JSON definitions for client scopes, like [config/terraform/jsons/scopes/client-scope-identity_credential.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/scopes/client-scope-identity_credential.json), [config/terraform/jsons/scopes/client-scope-kma_credential.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/scopes/client-scope-kma_credential.json), and [config/terraform/jsons/scopes/client-scope-stbk_westfalen_lippe.json](https://github.com/adorsys/keycloak-ssi-deployment/blob/main/config/terraform/jsons/scopes/client-scope-stbk_westfalen_lippe.json).
*   **`modules/`**: This directory contains reusable Terraform modules for different Keycloak resource types. This modular approach promotes code reusability, organization, and simplifies the management of complex Keycloak setups.
    *   `client_scopes/`: Module for managing Keycloak client scopes.
    *   `clients/`: Module for managing Keycloak clients.
    *   `keys/`: Module for managing Keycloak keys.
    *   `realm/`: Module for managing the Keycloak realm itself.
    *   `saml_idp/`: Module for configuring SAML Identity Providers.
    *   `users/`: Module for managing Keycloak users.
    *   `client_scopes/`: Module for managing Keycloak client scopes.
    *   `clients/`: Module for managing Keycloak clients.
    *   `keys/`: Module for managing Keycloak keys.
    *   `realm/`: Module for managing the Keycloak realm itself.
    *   `saml_idp/`: Module for configuring SAML Identity Providers.
    *   `users/`: Module for managing Keycloak users.

By using Terraform, you can define your Keycloak configuration as code, enabling version control, automated deployments, and consistent environments.