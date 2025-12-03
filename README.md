## Keycloak OpenID4VCI Deployment Wrapper

This repository is now a **thin deployment and infrastructure wrapper** around the upstream OAuth SIG / OpenID4VCI work.
The actual OpenID4VCI reference setup lives in the `keycloak-oauth-sig` submodule.

### Repository layout

- `keycloak-oauth-sig/`  
  Git submodule pointing to [`keycloak/keycloak-oauth-sig`](https://github.com/keycloak/keycloak-oauth-sig).  
  Within this submodule, the OpenID4VCI deployment lives under:

  - `keycloak-oauth-sig/OpenID4VCI-deployment/`
    - `config.yaml`, scripts, and docs for running Keycloak as an OpenID4VCI issuer.

- `Dockerfile.oid4vc-dev`  
  Dev-only Dockerfile that builds a Keycloak image from a specific branch (`KC_BRANCH`) of `adorsys/keycloak-oid4vc`.

- `infrastructure/`

  - `keycloak-chart/` – Helm chart for deploying the Keycloak OpenID4VCI issuer and wiring config/secrets.
  - `terraform/` – Terraform modules and examples for managing realms, clients, keys, scopes and users.

- `providers/`  
  Place for extra Keycloak provider JARs that you want to ship with the deployment image.

### Getting the code

Clone the repository with submodules:

```bash
git clone --recurse-submodules <this-repo-url>
cd keycloak-ssi-deployment
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

### Running the OpenID4VCI deployment (submodule)

For local OpenID4VCI experiments, work inside the submodule’s deployment folder:

```bash
cd keycloak-oauth-sig/oid4vci-deployment
```

If you have any custom provider JARs in this repository’s `providers/` directory and want them available when using the submodule CLI, copy them into the submodule deployment before running scripts:

```bash
mkdir -p keycloak-oauth-sig/oid4vci-deployment/providers
cp providers/*.jar keycloak-oauth-sig/oid4vci-deployment/providers/
```

From there, follow the upstream documentation in:

- `keycloak-oauth-sig/OpenID4VCI-deployment/Readme.md`
- `keycloak-oauth-sig/OpenID4VCI-deployment/docs/README_Advanced.md`

That documentation explains:

- how `config.yaml` and (optionally) `config.override.yaml` drive the deployment,
- how to start Keycloak with OpenID4VCI enabled,
- how to configure realms, clients, and scopes,
- how to request credentials using the provided scripts.

### Building a dev image with `Dockerfile.oid4vc-dev`

The `Dockerfile.oid4vc-dev` builds a Keycloak image from the `adorsys/keycloak-oid4vc` repository:

```bash
docker build \
  -f Dockerfile.oid4vc-dev \
  --build-arg KC_BRANCH=datev/develop \
  --build-arg KC_REPO=https://github.com/adorsys/keycloak-oid4vc.git \
  -t keycloak-oid4vc-dev .
```

You can then run it and pass configuration via environment variables, depending on your deployment style.
For production- or cluster-style deployments, prefer the Helm chart below.

### Deploying via Helm (Kubernetes)

The `infrastructure/keycloak-chart` directory contains a Helm chart for deploying the OpenID4VCI-enabled Keycloak into Kubernetes.  
For usage, values, and examples, see the dedicated chart documentation in:

- `infrastructure/keycloak-chart/README.md`

### Managing Keycloak configuration via Terraform

The `infrastructure/terraform` folder contains modules and an example setup to manage Keycloak configuration.  
For details on layout, variables, JSON inputs, and usage examples, see:

- `infrastructure/terraform/README.md`
