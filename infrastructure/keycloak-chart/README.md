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

## Deployment Scenarios

This chart supports two deployment paths:

1. **Custom Image (primary deployment)**  
   Use your own Keycloak image with OpenID4VCI support.
2. **Official Image Demo (`keycloak-demo`)**  
   Use upstream Keycloak image + plugin JAR + demo overlay values.

### Scenario 1: Custom Image (primary `keycloak` release)

1. Set image and base configuration in `values.yaml` (or your own values file):
   - `.image.repository` and `.image.tag`
   - database and TLS settings
2. Install or upgrade:

```bash
helm upgrade --install keycloak-openid4vci ./infrastructure/keycloak-chart -f my-values.yaml
```

3. Expose Keycloak via Ingress, LoadBalancer, or port-forwarding depending on environment.

### Scenario 2: Official Image Demo (`keycloak-demo`)

This scenario deploys a second release using `values-keycloak-demo.yaml` and reuses shared resources from the primary release.
The demo values file is generated from `values-keycloak-demo.yaml.tpl` to keep plugin version changes in one place.

#### Prerequisites

1. Deploy the primary `keycloak` release first.
   - Reused resources:
     - `keycloak-env-config` ConfigMap
     - `keycloak-secret` Secret
2. Create TLS secret for demo pod:
   - Generate cert/key:
     ```bash
     cd keycloak-ssi-deployment
     cd keycloak-oauth-sig/oid4vci-deployment
     ./keycloak-ssi.sh setup -d
     ```
   - Create TLS secret:
     ```bash
     cd keycloak-ssi-deployment
     kubectl -n datev-wallet create secret tls keycloak-demo-local-tls \
       --cert ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.crt.pem \
       --key  ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.key.pem \
       --dry-run=client -o yaml | kubectl apply -f -
     ```
3. Create/update plugin secret:
   ```bash
   cd keycloak-ssi-deployment
   PLUGIN_VERSION=1.1.6
   kubectl -n datev-wallet delete secret keycloak-providers 2>/dev/null || true
   kubectl -n datev-wallet create secret generic keycloak-providers \
     --from-file=keycloak-oid4vp-plugin-${PLUGIN_VERSION}.jar=./providers/keycloak-oid4vp-plugin-${PLUGIN_VERSION}.jar \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
4. Render `values-keycloak-demo.yaml` from template:
   ```bash
   cd keycloak-ssi-deployment
   ./infrastructure/keycloak-chart/scripts/render-values-keycloak-demo.sh "${PLUGIN_VERSION}"
   ```

#### Install

1. Deploy primary release:
   ```bash
   helm upgrade --install keycloak ./infrastructure/keycloak-chart -n datev-wallet -f ./infrastructure/keycloak-chart/values.yaml
   ```
2. Deploy demo release:
   ```bash
   helm upgrade --install keycloak-demo ./infrastructure/keycloak-chart -n datev-wallet \
     -f ./infrastructure/keycloak-chart/values.yaml \
     -f ./infrastructure/keycloak-chart/values-keycloak-demo.yaml \
     --wait
   ```

#### Notes

- `values-keycloak-demo.yaml` disables `createConfigMapJob` and `externalSecret` to avoid collisions with primary release.
- Demo focuses on upstream Keycloak image + HTTPS + OID4VCI feature; provider SPI jars come from `keycloak-providers` secret.
- PVC/PV AZ runbook for Postgres: if PVC already exists, read bound PV zone (`kubectl get pv <pv-name> -o yaml | rg topology.kubernetes.io/zone`) and set `postgres.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` in `values-keycloak-demo.yaml` accordingly.

### Local / Minikube testing

The `local_test_minikube` directory contains example manifests for External Secrets and RBAC in a local cluster.
Adapt these resources to your environment as needed.
