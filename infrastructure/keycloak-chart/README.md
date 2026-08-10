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
2. **Official Image PoS Demo (`pos-keycloak`)**
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

### Scenario 2: Official Image PoS Demo (`pos-keycloak`)

This scenario deploys an independent release using `values-keycloak-pos.yaml`. It does not require the primary `keycloak` release, `keycloak-env-config` ConfigMap, or `keycloak-secret` Secret.

The PoS demo release runs in the `pos-demo` namespace. Its Ingress, Service, Pods, PostgreSQL resources, secrets, and RBAC resources use the `pos-keycloak` prefix so their ownership is explicit. The values file uses YAML anchors (`plugin.fileName`, `plugin.mountPath`) so plugin version updates stay in one place.

#### Prerequisites

1. Verify External Secrets infrastructure:
   - `SecretStore/cash-registry-ui-secret-store` must be Ready in `pos-demo`.
   - AWS Secrets Manager secret `datev-wallet-secrets` must contain `DB_PASSWORD` and `KC_BOOTSTRAP_ADMIN_PASSWORD`.
   - The External Secrets controller IAM role must be allowed to read that secret.
   ```bash
   kubectl -n pos-demo get secretstore cash-registry-ui-secret-store
   ```
2. Create the TLS Secret for the demo pod:
   - Generate cert/key:
     ```bash
     cd keycloak-ssi-deployment
     cd keycloak-oauth-sig/oid4vci-deployment
     ./keycloak-ssi.sh setup -d
     ```
   - Create TLS secret:
     ```bash
     cd keycloak-ssi-deployment
     kubectl -n pos-demo create secret tls pos-keycloak-local-tls \
       --cert ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.crt.pem \
       --key  ./keycloak-oauth-sig/oid4vci-deployment/target/keycloak-server.key.pem \
       --dry-run=client -o yaml | kubectl apply -f -
     ```
3. Create/update the plugin Secret:

   ```bash
   cd keycloak-ssi-deployment
   PLUGIN_VERSION=1.1.9
   kubectl -n pos-demo create secret generic pos-keycloak-providers \
     --from-file=keycloak-oid4vp-plugin-${PLUGIN_VERSION}.jar=./providers/keycloak-oid4vp-plugin-${PLUGIN_VERSION}.jar \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

4. Update `plugin.fileName` and `plugin.mountPath` at the top of `values-keycloak-pos.yaml` if you are changing versions.

#### Install

Deploy the PoS Keycloak release alongside the old demo release:

```bash
helm upgrade --install pos-keycloak ./infrastructure/keycloak-chart -n pos-demo \
  -f ./infrastructure/keycloak-chart/values.yaml \
  -f ./infrastructure/keycloak-chart/values-keycloak-pos.yaml \
  --wait \
  --timeout 15m
```

Verify the standalone PoS resources:

```bash
kubectl -n pos-demo wait --for=condition=Ready \
  externalsecret/pos-keycloak-external-secret --timeout=180s
kubectl -n pos-demo get secret pos-keycloak-secret
kubectl -n pos-demo rollout status \
  statefulset/pos-keycloak-postgres --timeout=10m
kubectl -n pos-demo rollout status \
  deployment/pos-keycloak --timeout=10m
kubectl -n pos-demo get pods,services,endpoints,pvc \
  -l app.kubernetes.io/instance=pos-keycloak -o wide
```

#### Notes

- `values-keycloak-pos.yaml` disables the inherited ConfigMap job, ConfigMap init container, and ConfigMap volume because the official Keycloak image is configured directly through container environment variables.
- The PoS ExternalSecret and generated Secret use `pos-keycloak` names and do not collide with the primary release.
- The demo database password and bootstrap-admin password still come from the shared AWS Secrets Manager source, but no Kubernetes resource from the primary release is reused.
- Demo focuses on upstream Keycloak image + HTTPS + OID4VCI feature; provider SPI jars come from the `pos-keycloak-providers` Secret.
- A fresh demo database has no hard-coded availability-zone affinity. Kubernetes and the storage provisioner select a compatible zone.
- To mount a recovered database PVC, set `postgres.persistence.existingClaim=<pvc-name>` and verify that Ready worker nodes exist in the PV's availability zone before upgrading.

### Local / Minikube testing

The `local_test_minikube` directory contains example manifests for External Secrets and RBAC in a local cluster.
Adapt these resources to your environment as needed.
