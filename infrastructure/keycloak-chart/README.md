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

---

## Deploy `keycloak-demo` with Official Keycloak Image

This chart can also deploy a “demo” Keycloak instance using an **official upstream image** (example: `quay.io/keycloak/keycloak:26.5.6`) while still enabling the Keycloak **OID4VCI experimental feature** (`oid4vc-vci`).

The demo deployment is implemented via an additional Helm values file: `values-keycloak-demo.yaml`.

### Prerequisites
1. Deploy the primary `keycloak` release first.
   - The demo reuses the shared resources created by the primary release:
     - `keycloak-env-config` ConfigMap
     - `keycloak-secret` Secret
2. Create a TLS secret for the demo pod (because the demo uses TLS non-dev mode).
   - Generate the cert/key locally:
     ```bash
     cd keycloak-ssi-deployment
     cd keycloak-oauth-sig/oid4vci-deployment
     ./keycloak-ssi.sh setup -d
     ```
   - Create the Kubernetes TLS secret:
     ```bash
     cd keycloak-ssi-deployment
     kubectl -n datev-wallet create secret tls keycloak-demo-local-tls \
       --cert ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.crt.pem \
       --key  ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.key.pem \
       --dry-run=client -o yaml | kubectl apply -f -
     ```

3. Mount the `oid4vp` plugin JAR into the demo Keycloak.
   - Create a secret named `keycloak-providers` containing your provider JAR(s):
     ```bash
     cd keycloak-ssi-deployment
     kubectl -n datev-wallet delete secret keycloak-providers 2>/dev/null || true
     kubectl -n datev-wallet create secret generic keycloak-providers \
       --from-file=keycloak-oid4vp-plugin-1.1.5.jar=./providers/keycloak-oid4vp-plugin-1.1.5.jar \
       --dry-run=client -o yaml | kubectl apply -f -
     ```
   - The chart mounts this secret into `/opt/keycloak/providers/` (currently only the `keycloak-oid4vp-plugin-*.jar` is mounted).

### Install
1. (Primary) Deploy your normal `keycloak` release (custom image):
   ```bash
   helm upgrade --install keycloak ./infrastructure/keycloak-chart -n datev-wallet -f ./infrastructure/keycloak-chart/values.yaml
   ```
2. (Demo) Deploy `keycloak-demo` with the official Keycloak image:
   ```bash
   helm upgrade --install keycloak-demo ./infrastructure/keycloak-chart -n datev-wallet \
     -f ./infrastructure/keycloak-chart/values.yaml \
     -f ./infrastructure/keycloak-chart/values-keycloak-demo.yaml \
     --wait
   ```

Notes:
- `values-keycloak-demo.yaml` disables `createConfigMapJob` and `externalSecret` to avoid name collisions with the primary `keycloak` release.
- The demo focuses on “official image + HTTPS + OID4VCI feature”. Provider SPI jars are mounted via the `keycloak-providers` secret (from `./providers/`).
- PVC/PV AZ runbook for Postgres: when a PVC already exists, first read the bound PV zone (`kubectl get pv <pv-name> -o yaml | rg topology.kubernetes.io/zone`), then set `postgres.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` in `values-keycloak-demo.yaml` to that same AZ before upgrading.
