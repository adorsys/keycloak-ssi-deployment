# Keycloak OpenID4VCI Helm Chart

This Helm chart deploys a **Keycloak instance** configured as an **OpenID for Verifiable Credential Issuance (OpenID4VCI) issuer**.  
It is designed to work with the images and configuration produced by this repository.

> The chart automates deployment, secrets management, and configuration of Keycloak for OpenID4VCI.

---

## Prerequisites

Before installing this chart, ensure you have:

- A container registry containing a **Keycloak image with OpenID4VCI support**  
  (e.g., built using `Dockerfile.oid4vc-dev` or an equivalent upstream image)
- A **PostgreSQL database** or another database supported by your Keycloak image
- A **Kubernetes cluster** with:
  - Helm v3 installed
  - Access to the registry where your Keycloak image is published

---

## Chart Contents

| File / Directory                   | Description                                                                             |
| ---------------------------------- | --------------------------------------------------------------------------------------- |
| `Chart.yaml` / `Chart.lock`        | Chart metadata and dependency lock                                                      |
| `values.yaml`                      | Default configuration values, including image, database, TLS, and environment variables |
| `templates/create-config-map.yaml` | Creates a `ConfigMap` for Keycloak configuration (e.g., `config.yaml`)                  |
| `templates/external-secrets.yaml`  | Optional integration for fetching secrets (passwords, keys, etc.) via External Secrets  |
| `templates/job-rbac.yaml`          | RBAC for Helm hooks or jobs requiring elevated permissions                              |
| `local_test_minikube/`             | Example manifests for local/Minikube testing (RBAC and SecretStore)                     |

---

## Typical Usage

### 1. Set Image and Configuration

Copy `values.yaml` and adjust at minimum:

- `.image.repository` and `.image.tag` to point to your Keycloak image
- Database and TLS settings as needed

### 2. Install or Upgrade the Release

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
