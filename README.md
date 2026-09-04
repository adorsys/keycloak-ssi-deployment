## Keycloak OpenID4VCI Deployment Wrapper

This repository is now a **thin deployment and infrastructure wrapper** around the upstream [Keycloak OAuth SIG](https://github.com/keycloak/keycloak-oauth-sig/tree/main/oid4vci-deployment).
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

### Quick setup

From the repository root, run in order:

```bash
./keycloak-ssi.sh setup    # Start DB + Keycloak (wait until ready)
./keycloak-ssi.sh config   # Configure realm, clients, keys, users
```

Then run a credential test, for example:
`./keycloak-ssi.sh test preauth IdentityCredential`

For the Keycloak-main POC that issues an mDoc to a wallet and verifies it for OID4VP login with issuer-scoped EUDI
trust-list enforcement, see [LOCAL_MDOC_ISSUANCE_AND_LOGIN.md](./LOCAL_MDOC_ISSUANCE_AND_LOGIN.md).

For a plain-language explanation of the OID4VP plugin's complete authentication flow and its `self`, `x5c`, and
`eudi_pid_trust_list` trust modes, see [OID4VP_PLUGIN_FLOW_AND_TRUST.md](./OID4VP_PLUGIN_FLOW_AND_TRUST.md).

---

#### Adding custom client scopes

You can add your own client scopes without touching the submodule by:

1. Creating a `client-scopes.json` file at the **repository root**.
   - Use the same JSON structure as the scope definitions under  
     `infrastructure/terraform/jsons/scopes/*.json` (name, protocol, protocolMappers, attributes, etc.).
   - Each entry in the top-level JSON array represents one client scope to create.
2. Running:

   ```bash
   ./keycloak-ssi.sh addClientScopes
   ```

This command reads `client-scopes.json`, **creates the provided client scopes**, and **assigns them as optional scopes** to the
clients you configure (see below). By default those are `openid4vc-rest-api` and `oid4vc-demo-public` (skipping scopes or assignments that already exist).

You can create or edit `config-override.yaml` at the **repository root** and define which client IDs receive the optional scopes. The script reads the variable from that file and uses it when you run `./keycloak-ssi.sh addClientScopes`. Example:

```yaml
# config-override.yaml (repo root, gitignored)
add_client_scopes:
  target_clients: "openid4vc-rest-api oid4vc-demo-public"
```

Use a space or comma-separated list of client IDs. The wrapper syncs this file into the submodule before running, so changes take effect on the next `addClientScopes` run.

### Using the wrapper CLI

From the repository root you can use the wrapper script instead of calling the submodule directly:

```bash
./keycloak-ssi.sh setup                               # Start the OID4VCI test deployment (DB + Keycloak via submodule)
./keycloak-ssi.sh config                              # Configure realm, clients, keys, and users in the running Keycloak
./keycloak-ssi.sh test preauth IdentityCredential     # Run a pre-authorized code flow test for a given credential type
./keycloak-ssi.sh test authcode IdentityCredential    # Run an authorization code flow test for a given credential type
./keycloak-ssi.sh terraform destroy -auto-approve     # Run Terraform destroy against the configured Keycloak
./keycloak-ssi.sh terraform apply -auto-approve       # Run Terraform apply against the configured Keycloak
./keycloak-ssi.sh addClientScopes                     # Create and assign client scopes using the direct API helper
./keycloak-ssi.sh install                             # Install the wrapper CLI as a global `keycloak-ssi` command
./keycloak-ssi.sh uninstall                           # Remove the globally installed `keycloak-ssi` command
./keycloak-ssi.sh help                                # Show available wrapper and delegated submodule commands
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
