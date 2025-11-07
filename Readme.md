# Keycloak SSI Deployment

This project provides a robust and flexible solution for integrating Self-Sovereign Identity (SSI) capabilities with Keycloak, an open-source Identity and Access Management (IAM) solution. It enables organizations to issue, verify, and manage verifiable credentials within a familiar Keycloak environment.

## Documentation

For comprehensive documentation, including setup, configuration, credential management, testing, deployment, and customization, please visit our [documentation site](https://adorsys.github.io/keycloak-ssi-deployment/).

## Quick Start

To get Keycloak with OID4VCI (OpenID for Verifiable Credentials Issuance) support up and running quickly:

### Prerequisites

*   **Docker**
*   **Docker Compose**
*   **Git**
*   **OpenSSL**
*   **Keytool**
*   **jq (Optional)**

Ensure your `.env` file is configured correctly.

### Start Keycloak

```bash
./0.start-kc-oid4vci.sh
```

This script will build Docker images, start Keycloak, and configure the realm for SSI.

### Proceed with Keycloak config

```bash
./1.oid4vci_test_deployment.sh
```


```bash
2.configure_user_4_account_client.sh
```

### Stop Keycloak

```bash
./kc-stop.sh
```

### Testing Credential Retrieval


```bash
3.request_credentials_with_auth_code_flow.sh
```

```bash
3.retrieve_IdentityCredential.sh
```

```bash
3.retrieve_KMACredential.sh
```

```bash
3.retrieve_SteuerberaterCredential.sh
```


## Key Features

*   **Keycloak Integration**: Leverages Keycloak for user authentication and authorization.
*   **OID4VCI Support**: Implements OpenID for Verifiable Credential Issuance.
*   **Terraform Configuration**: Manages Keycloak resources as code.
*   **Helm Chart**: Facilitates Kubernetes deployment.
*   **Credential Management**: Tools for key generation and verifiable credential issuance.
*   **SD-JWT Support**: Supports Self-Describing JSON Web Tokens for selective disclosure.

## Contributing

We welcome contributions! Please refer to the documentation site for guidelines on how to contribute.

## License

This project is licensed under the [Apache 2.0 License](LICENSE).
