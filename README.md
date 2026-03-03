## Keycloak OpenID4VCI Deployment Wrapper

This repository is now a **thin deployment and infrastructure wrapper** around the upstream OAuth SIG / OpenID4VCI work.
The actual OpenID4VCI reference setup lives in the `keycloak-oauth-sig` submodule.

---

## Repository Layout

| Path                                     | Description                                                                                                                      |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `keycloak-oauth-sig/`                    | Git submodule pointing to the upstream repo (`keycloak/keycloak-oauth-sig`). The OpenID4VCI deployment lives inside this module. |
| `keycloak-oauth-sig/oid4vci-deployment/` | Contains `config.yaml`, scripts, and docs for running Keycloak as an OpenID4VCI issuer.                                          |
| `Dockerfile.oid4vc-dev`                  | Dev-only Dockerfile for building a Keycloak image from a specific branch of `adorsys/keycloak-oid4vc`.                           |
| `infrastructure/keycloak-chart/`         | Helm chart for deploying the OpenID4VCI-enabled Keycloak instance.                                                               |
| `infrastructure/terraform/`              | Terraform modules and examples for managing realms, clients, keys, scopes, users, and status list support.                       |
| `providers/`                             | Extra Keycloak provider JARs (e.g. status list and OID4VP plugins) to bundle with the deployment image.                          |

---

### Getting the code

Clone the repository (including its submodule):

```bash
git clone --recurse-submodules https://github.com/adorsys/keycloak-ssi-deployment.git
cd keycloak-ssi-deployment
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive # Initialize and populate the submodule
```

To fetch updates from the submodule’s tracked branch (main):

```bash
git submodule update --remote --merge   # Pull latest commit from remote branch defined in .gitmodules
```

---

### Using the wrapper CLI

From the repository root you can use the wrapper script instead of calling the submodule directly:

```bash
./keycloak-ssi.sh setup         
./keycloak-ssi.sh config        
./keycloak-ssi.sh test preauth ...
./keycloak-ssi.sh test authcode ...      
./keycloak-ssi.sh terraform destroy -auto-approve         
./keycloak-ssi.sh terraform apply -auto-approve          
./keycloak-ssi.sh addClientScopes          
./keycloak-ssi.sh install         
./keycloak-ssi.sh uninstall         
./keycloak-ssi.sh help          
```

The wrapper keeps configuration and custom providers in sync with the submodule, so you usually do **not** need to copy
files into `keycloak-oauth-sig/oid4vci-deployment` manually.

---

### Running the OpenID4VCI deployment (submodule)

For local OpenID4VCI experiments, work inside the submodule’s deployment folder:

```bash
cd keycloak-oauth-sig/oid4vci-deployment
```

From there, follow the upstream documentation in:

- [Readme.md](keycloak-oauth-sig/oid4vci-deployment/Readme.md)
- [README_Advanced.md](keycloak-oauth-sig/oid4vci-deployment/docs/README_Advanced.md)

That documentation explains:

- how `config.yaml` and (optionally) `config.override.yaml` drive the deployment,
- how to start Keycloak with OpenID4VCI enabled,
- how to configure realms, clients, and scopes,
- how to request credentials using the provided scripts.

---

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

---

### Deploying via Helm (Kubernetes)

The `infrastructure/keycloak-chart` directory contains a Helm chart for deploying the OpenID4VCI-enabled Keycloak into Kubernetes.  
For usage, values, and examples, see the dedicated chart documentation in:

- [Helm Chart README.md](infrastructure/keycloak-chart/README.md)

---

### Managing Keycloak configuration via Terraform

The `infrastructure/terraform` folder contains modules and an example setup to manage Keycloak configuration.  
For details on layout, variables, JSON inputs, and usage examples, see:

- [Terraform Config README.md](infrastructure/terraform/README.md)
