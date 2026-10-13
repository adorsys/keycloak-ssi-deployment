## Keycloak OpenID4VCI Deployment Wrapper

This repository is a **deployment and infrastructure wrapper** around the upstream [Keycloak OAuth SIG](https://github.com/keycloak/keycloak-oauth-sig/tree/main/oid4vci-deployment).
The upstream OpenID4VCI toolkit remains unchanged in the `keycloak-oauth-sig` submodule. SSI-owned configuration and startup scripts layer the Keycloak 26.8.0 and OID4VP plugin deployment on top of it.

---

## Repository Layout

| Path                                     | Description                                                                                                                      |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `keycloak-oauth-sig/`                    | Read-only Git submodule pinned to an upstream `keycloak/keycloak-oauth-sig` commit from `main`.                                  |
| `keycloak-oauth-sig/oid4vci-deployment/` | Contains the upstream OpenID4VCI deployment toolkit.                                                                             |
| `deployment/keycloak/`                   | SSI-owned Keycloak 26.8.0 configuration and Docker Compose overrides.                                                           |
| `Dockerfile.oid4vc-dev`                  | Dev-only Dockerfile for building a Keycloak image from a specific branch of `adorsys/keycloak-oid4vc`.                           |
| `infrastructure/keycloak-chart/`         | Helm chart for deploying the OpenID4VCI-enabled Keycloak instance.                                                               |
| `infrastructure/terraform/`              | Terraform modules and examples for managing realms, clients, keys, scopes, users, and status list support.                       |
| `providers/`                             | SSI-managed Keycloak provider JARs installed during startup.                                                                     |

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

Review and commit the resulting submodule pointer after verifying the SSI deployment wrapper against the new upstream commit. Do not commit deployment-specific changes inside the submodule.

---

### Quick setup

From the repository root, run in order:

```bash
./keycloak-ssi.sh setup    # Start DB + Keycloak (wait until ready)
./keycloak-ssi.sh config   # Configure realm, clients, keys, users
```

`setup` uses the SSI-owned deployment layer to:

- install Keycloak 26.8.0 and the OID4VP plugin 1.3.4;
- enable the Keycloak credential-offer REST feature;
- configure the plugin-managed realms;
- migrate a preserved Keycloak database with the `update` strategy; and
- restart Keycloak without deleting existing realms or database volumes.

Use `./keycloak-ssi.sh setup --clean` only when an explicit fresh database is required.

For environment-specific credentials or host settings, copy the example and edit the ignored file:

```bash
cp config-override.yaml.example config-override.yaml
```

Values in `config-override.yaml` override the committed defaults in `deployment/keycloak/config.override.yaml`.

#### Keycloak 26.8 issuer signing keystore

The issuer signing keystore is managed outside the startup script.
`./keycloak-ssi.sh setup` does not create, modify, or download issuer
certificates. The PKCS#12 must contain an ES256 `PrivateKeyEntry` and the
certificate chain for that same key.

For the Keycloak Java keystore provider, configure
`KC_SPI_KEYS__JAVA_KEYSTORE__KEYSTORES_PATH` to the keystore root. Put each
realm's keystore under a directory named for that realm, and set that realm's
Terraform `oid4vc_keystore_path` to the resulting file path. Realms may use
copies of the same keystore when they intentionally share the same issuer key.
Keep the keystore and its password out of Git.

Keycloak documents this layout in the [26.8 Upgrading Guide, “Files for the Java Keystore provider should be placed inside a fixed realm directory”](https://www.keycloak.org/docs/26.8.0/upgrading/#_files_for_the_java_keystore_provider_should_be_placed_inside_a_fixed_realm_directory). The keystores root and realm-specific file path are covered in the [26.8 Server Administration Guide, “Loading keys from a Java Keystore”](https://www.keycloak.org/docs/26.8.0/server_admin/#loading-keys-from-a-java-keystore): the startup option sets the root, and the realm's `java-keystore` provider `keystore` field points to the file under `<root>/<realm-name>/`. The environment-variable spelling for that startup option, `KC_SPI_KEYS__JAVA_KEYSTORE__KEYSTORES_PATH`, is listed under [`keys` → `java-keystore` in the All Provider Configuration](https://www.keycloak.org/server/all-provider-config#_java_keystore) (the provider configuration reference is not versioned).

#### Local issuance testing vs. German-wallet testing

For a local issuance smoke test, a developer needs a PKCS#12 signing keystore
with the expected ES256 private-key alias and certificate chain, plus a local
secret tfvars file containing that keystore's password, alias, realm name, and
runtime-visible path. For example, with `local-keystores` as the local keystore root:

```text
local-keystores/
└── oid4vc-vci/
    └── issuer-signing.p12
```

In the ignored local tfvars file, set the realm, absolute keystore path,
keystore password, type, alias, and signed-metadata algorithm. For example:

```hcl
realm                       = "oid4vc-vci"
oid4vc_keystore_path        = "/absolute/path/to/local-keystores/oid4vc-vci/issuer-signing.p12"
oid4vc_keystore_password    = "<local-keystore-password>"
oid4vc_keystore_type        = "PKCS12"
oid4vc_ecdsa_key_alias      = "ecdsa_team_key"
oid4vci_signed_metadata_alg = "ES256"
```

The configured alias must be a `PrivateKeyEntry`; its private key must
correspond to the leaf certificate. Export the keystore root into the Keycloak
process environment, start Keycloak, then apply Terraform for that realm:

```bash
export KC_SPI_KEYS__JAVA_KEYSTORE__KEYSTORES_PATH="/absolute/path/to/local-keystores"
./keycloak-ssi.sh setup -d
terraform -chdir=infrastructure/terraform apply -var-file=secrets-local.tfvars
```

A successful local issuance test only confirms the local Keycloak flow and
keystore configuration. It does not establish German-wallet trust. For that,
the leaf must be the sandbox-issued issuer access certificate for the same
private key, with its CA chain, and the local Keycloak endpoint must be
reachable by the wallet over HTTPS. A self-signed or development-CA chain may
be useful for isolated local testing, but it is not trusted by the German
wallet sandbox.

The wrapper discovers provider JARs from `providers/` without hard-coding a plugin version. Keep exactly one `keycloak-oid4vp-plugin-*.jar` in that directory. To upgrade the plugin, replace the existing JAR with the new version; no wrapper-script change is required.

For Docker Compose commands, the merged YAML configuration remains the source of truth. The wrapper generates a temporary `.env` adapter, passes it explicitly to Compose, and removes it after the command completes. The SSI Compose file only mounts providers and maps those generated values into the Keycloak container.

Then run a credential test, for example:
`./keycloak-ssi.sh test preauth IdentityCredential`

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

You can also define which client IDs receive optional scopes in `config-override.yaml` at the repository root. The wrapper merges this file over the SSI defaults before running. Example:

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
