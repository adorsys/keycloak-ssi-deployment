## Keycloak OpenID4VCI Helm Chart

This chart deploys a Keycloak instance configured to act as an OpenID for Verifiable Credential Issuance (OpenID4VCI) issuer.
It is designed to work with the images and configuration produced by this repository.

### Prerequisites

- A container registry containing a Keycloak image with OpenID4VCI support  
  (for example, built using `Dockerfile.oid4vc-dev` or an equivalent upstream image).
- A PostgreSQL database or another database supported by your Keycloak image.
- A Kubernetes cluster with:
  - Helm v3 installed,
  - access to the registry where your Keycloak image is published.

### Chart contents

- `Chart.yaml` / `Chart.lock` – chart metadata and dependency lock.
- `values.yaml` – default configuration values:
  - image repository, tag, and pull policy,
  - database connection parameters,
  - Keycloak admin credentials,
  - TLS / HTTPS configuration,
  - additional environment variables for Keycloak.
- `templates/`:
  - `create-config-map.yaml` – creates a `ConfigMap` for Keycloak configuration (for example a `config.yaml`).
  - `external-secrets.yml` – optional integration with External Secrets to pull secrets (passwords, keys, etc.).
  - `job-rbac.yaml` – RBAC for any Helm hooks or jobs that might need elevated permissions.
- `local_test_minikube/` – example manifests for local/minikube testing (RBAC and SecretStore).

### Typical usage

1. **Set image and configuration**

   Copy `values.yaml` and adjust at least:

   - `.image.repository` and `.image.tag` to point to your Keycloak image,
   - database and TLS settings.

2. **Install or upgrade the release**

   From the repository root:

   ```bash
   helm upgrade --install keycloak-openid4vci ./infrastructure/keycloak-chart -f my-values.yaml
   ```

3. **Expose Keycloak**

   Depending on your environment, expose the Keycloak service using:

   - an Ingress,
   - a LoadBalancer service,
   - or port-forwarding for local testing.

### Local / Minikube testing

The `local_test_minikube` directory contains example manifests to help you integrate with
External Secrets and RBAC in a local cluster.  
Adapt these resources to your environment as needed.
