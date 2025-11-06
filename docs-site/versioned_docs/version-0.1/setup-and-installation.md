# Setup and Installation

This section guides you through setting up and installing the Keycloak SSI Deployment.

## Prerequisites

Before you begin, ensure you have the following installed on your system:

*   **Docker**: For containerizing Keycloak and other services.
*   **Docker Compose**: For defining and running multi-container Docker applications.
*   **Git**: For cloning the repository.

## Cloning the Repository

First, clone the `keycloak-ssi-deployment` repository to your local machine:

```bash
git clone https://github.com/adorsys/keycloak-ssi-deployment.git
cd keycloak-ssi-deployment
```

## Starting Keycloak

The project includes several scripts to help you start and manage the Keycloak instance.

To start Keycloak with OID4VCI (OpenID for Verifiable Credentials Issuance) support, execute the following script:

```bash
./0.start-kc-oid4vci.sh
```

This script will:
*   Build the necessary Docker images.
*   Start the Keycloak container.
*   Configure the Keycloak realm with initial settings for SSI.

You can verify that Keycloak is running by accessing its administration console (usually at `http://localhost:8080/auth/admin`).

To stop the Keycloak instance, use the following script:

```bash
./kc-stop.sh