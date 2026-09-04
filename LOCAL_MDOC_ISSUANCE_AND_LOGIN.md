# Local mDoc issuance and OID4VP login

This guide runs one local Keycloak instance as both:

- an OpenID4VCI Credential Issuer that issues an `mso_mdoc` PID credential to a wallet; and
- an OpenID4VP Verifier that accepts that credential and resolves the Keycloak user from its subject claim.

The setup builds Keycloak `main` from `https://github.com/adorsys/keycloak-oid4vc.git` (configured via `keycloak.repo_url` in `config-override.yaml`) because mDoc issuance is not yet available
in the Keycloak release used by the normal deployment. No issuer-side Java code is patched by this setup.

The complete flow has been exercised successfully with Paradym: Keycloak issued the mDoc to the wallet, the wallet
presented it back to the OID4VP plugin, and Keycloak completed user login. This is the baseline end-to-end check for the
local environment. A wallet that fails against the same environment can therefore be investigated as a separate
interoperability problem instead of assuming that mDoc issuance or verification is generally broken.

## What this local environment contains

There are four cooperating pieces:

```text
Wallet
  |  OpenID4VCI: receive an mDoc
  |  OpenID4VP: present the mDoc
  v
Keycloak main on https://localhost:10443
  |-- Credential Issuer implemented by Keycloak main
  `-- Verifier implemented by the locally built OID4VP plugin
          |
          | HTTPS fetch and JWS verification
          v
     Test PID Provider LoTE on https://localhost:9443/pid-providers.jwt
```

PostgreSQL stores the Keycloak realm and users. Terraform creates the repeatable realm configuration. The small local
LoTE server supplies the issuer-specific trust information used by the verifier; it is not involved in issuing the
credential to the wallet.

## Security model being tested

The primary identity is not the subject claim alone. The verifier enforces this sequence:

1. Verify the signed PID Provider List of Trusted Entities (LoTE) with the separately pinned LoTE signing
   certificate.
2. Resolve the configured provider identifier inside that LoTE without flattening all provider certificates into one
   pool.
3. Select that provider's `PID/Issuance` service and only its `ServiceDigitalIdentity` certificates.
4. Verify the mDoc `issuerAuth` certificate chain using those provider-specific certificates.
5. Return the provider identifier as the verified credential issuer.
6. Confirm it equals the issuer configured for the primary mDoc requirement.
7. Read the namespace-qualified subject claim and resolve the Keycloak user by ID.

For this environment, the effective authentication identity is therefore:

```text
(urn:adorsys:local:pid-provider:keycloak,
 eu.europa.ec.eudi.pid.1/personal_administrative_number)
```

The profile accepts exactly one configured PID Provider. Enforcing that issuer before user lookup is equivalent to
using the `(issuer, subject)` pair for this single-issuer profile. It does not implement trust-on-first-login and does
not write an issuer attribute onto a user.

## SD-JWT is already issuer-bound

The local SD-JWT profile uses `trust: [{ "type": "self" }]`.

- `SdJwtAuthRequirements` requires the signed `iss` claim to equal the current Keycloak realm issuer by default.
- `SelfTrustedSdJwtIssuer` verifies the JWT with enabled signing keys from that same realm.
- User lookup then uses the configured `subjectClaim`, which is `sub` here.

Its effective identity is consequently `(Keycloak realm issuer, sub)`.

The additional change in `EudiPidTrustedSdJwtIssuer` does not alter this self-issued path. It only hardens the separate
EUDI trust-list SD-JWT mode. That mode already compared the JWT `iss` value with `trust[].issuer`, but previously
verified its `x5c` chain against certificates flattened from every provider in the LoTE. It now resolves the configured
provider first and validates against only that provider's certificates. This prevents a credential from Provider B
from being accepted under Provider A's configuration when both providers occur in the same signed LoTE.

## Repository layout

The runner uses these local checkouts:

```text
/home/adorsys/adorsys_dev/keycloak-ssi-deployment
/home/adorsys/adorsys_dev/keycloak-oid4vp-plugin
```

The `keycloak-oauth-sig` submodule inside `keycloak-ssi-deployment` provides the upstream deployment harness
(`helper.sh`, Docker Compose, and build scripts). It clones Keycloak from the configured `repo_url` into
`keycloak-oauth-sig/oid4vci-deployment/target/keycloak_main` and builds it. The runner copies configuration and the
staged provider into the submodule's deployment area but does not require changes to the upstream Java source.

With the current HTTPS `repo_url`, `/home/adorsys/adorsys_dev/keycloak-oid4vc` is useful for reviewing Keycloak-main
code but is not read by the runner. To build that checkout instead, set:

```yaml
keycloak:
  repo_url: "file:///home/adorsys/adorsys_dev/keycloak-oid4vc"
```

Important files are:

```text
config-override.yaml
infrastructure/terraform/secrets-local.tfvars
infrastructure/terraform/main.tf
infrastructure/terraform/jsons/scopes/*.json
scripts/local-mdoc/local-mdoc-env.sh
scripts/local-mdoc/generate-test-lote.sh
scripts/local-mdoc/serve-test-lote.py
```

Generated files, keys, certificates, the test LoTE, and isolated Terraform state are kept below
`target/local-mdoc/`.

The generated runtime directory normally contains:

```text
target/local-mdoc/
├── lote-signing.key.pem       # private test key that signs the LoTE JWS
├── lote-signing.crt.pem       # corresponding test signing certificate
├── lote-signing.crt.der       # DER form pinned in the verifier profile
├── mdoc-issuer.crt.der        # certificate exported from Keycloak's issuer keystore
├── pid-providers.jwt          # signed test PID Provider LoTE
├── lote-server.log
├── lote-server.pid
├── terraform-work/            # disposable copy of the Terraform configuration
└── terraform.tfstate          # isolated local state; not the repository S3 state
```

## Prerequisites

Install or make available:

- Java 21;
- Maven through each repository's `./mvnw` or system `mvn`;
- Docker with Compose;
- Terraform;
- `jq`, `yq`, `rsync`, `curl`, `openssl`, `keytool`, and Python 3.

The two required local repositories must already exist at the paths above. An alternative plugin path can be supplied with
`OID4VP_PLUGIN_SOURCE_DIR`.

### Local secrets

Create `infrastructure/terraform/secrets-local.tfvars` if it does not already exist. Keep real values out of Git. The
existing Terraform modules require at least:

```hcl
admin_password                   = "<local-admin-password>"
initial_password                 = "<password-for-francis>"
openid4vc_rest_api_client_secret = "<local-client-secret>"
keycloak_url                     = "https://localhost:10443"
enable_rsa_keys                  = false
```

The runner explicitly uses the bootstrap password and URL loaded from `config-override.yaml`, so stale endpoint/admin
values in an existing secrets file cannot redirect this local test to another Keycloak instance.

### Local deployment override

`config-override.yaml` is intentionally ignored by Git. For this setup it selects Keycloak main, enables preauth code and rest credential offers, sets scope allowlists, and configures isolated ports:

```yaml
keycloak:
  version: "999.0.0-SNAPSHOT"
  target_branch: "main"
  oid4vci_dir: "keycloak_main"
  repo_url: "https://github.com/adorsys/keycloak-oid4vc.git"
  enable_preauth_code: true
  enable_rest_credential_offer: true
  bootstrap:
    admin_username: "admin"
    admin_password: "<same local bootstrap password>"

database:
  exposed_port: "15433"
  username: "postgres"
  password: "postgres"

credentials:
  enabled: "PIDCredential"

oid4vp_auth:
  managed_realms: "oid4vc-vci"
  verbose_errors: true

keycloak_endpoints:
  https_port: 10443
  admin_addr: "https://localhost:${KEYCLOAK_HTTPS_PORT}"

start_command: "start --hostname-strict=false --log-level=info --https-port=${KEYCLOAK_HTTPS_PORT} --https-certificate-file=${SSL_SERVER_CERT} --https-certificate-key-file=${SSL_SERVER_KEY} --truststore-paths=${SSL_SERVER_CERT} --spi-realm-restapi-extension-oid4vp-auth-managed-realms=${OID4VP_AUTH_MANAGED_REALMS} --spi-realm-restapi-extension-oid4vp-auth-verbose-errors=${OID4VP_AUTH_VERBOSE_ERRORS}"
```

`credentials.enabled` specifies the comma-separated allowlist of client scopes to import and configure. The current
local override selects only `PIDCredential`. When the value is set:

- Terraform imports and configures only the selected scopes from `infrastructure/terraform/jsons/scopes/` and assigns them to clients.
- If `PIDCredential` is enabled, the runner automatically enables the `oid4vc-mdoc` Keycloak feature.
- If omitted or empty, Terraform installs all available scopes under `jsons/scopes/`.

Port `10443` avoids a separate development Keycloak commonly running on `8443`. PostgreSQL uses host port `15433` to
avoid other local PostgreSQL instances.

## Start and configure everything

From the deployment repository:

```bash
cd /home/adorsys/adorsys_dev/keycloak-ssi-deployment
./scripts/local-mdoc/local-mdoc-env.sh start
```

The command performs the complete setup:

1. Copies the repository's `config-override.yaml` into the upstream deployment harness and loads it through
   `helper.sh`. This resolves the source repository, Keycloak version, ports, passwords, enabled credentials, keystore,
   and TLS paths in one place.
2. Stops an already running local Keycloak process and brings down the harness database with its volume. This produces
   a clean, reproducible database and avoids accidentally connecting the new Keycloak process to old realm state.
3. Builds `KEYCLOAK_FEATURES` from the configured features. It adds `oid4vc-mdoc` when `PIDCredential` is enabled,
   while the override enables the pre-authorized-code and REST credential-offer features.
4. Clean-builds the OID4VP plugin from `/home/adorsys/adorsys_dev/keycloak-oid4vp-plugin` and stages its shaded provider
   JAR as `providers/keycloak-oid4vp-plugin-1.1.9.jar`. The fixed filename is only the deployment staging name; the
   Maven project version remains inside the JAR.
5. Invokes `./keycloak-ssi.sh setup -d`. The upstream harness obtains Keycloak branch `main` from
   `https://github.com/adorsys/keycloak-oid4vc.git`, builds `999.0.0-SNAPSHOT` when needed, prepares the distribution,
   and starts PostgreSQL and Keycloak.
6. Loads only the OID4VP provider for this test. The unrelated local status-list JAR is intentionally excluded because
   its bundled dependencies are not compatible with Keycloak main; the normal wrapper behavior remains unchanged.
7. Generates or reuses the local LoTE signing key, exports Keycloak's current ES256 issuer certificate, builds a new
   signed ETSI-shaped LoTE, and starts its HTTPS server on port `9443`.
8. Waits until Keycloak is reachable before attempting administrative configuration.
9. Copies Terraform below `target/local-mdoc/terraform-work/` without `backend.tf`. This deliberately avoids the
   repository's S3 backend and uses `target/local-mdoc/terraform.tfstate` for the disposable POC.
10. Converts `credentials.enabled` into Terraform's `enabled_scope_names`, then applies the realm, user, clients,
    selected credential scopes, ES256 Java-keystore provider, OID4VP flow, and authentication profiles.
11. Grants `PIDCredential` to `francis` through Keycloak main's per-user verifiable-credential API.
12. Checks that the signed LoTE is downloadable and that Keycloak issuer metadata advertises
    `PIDCredential` as `mso_mdoc`.

Expected final output includes:

```text
Apply complete!
Local mDoc environment is ready.
Issuer metadata: https://localhost:10443/realms/oid4vc-vci/.well-known/openid-credential-issuer
Signed PID LoTE: https://localhost:9443/pid-providers.jwt
PID Provider identifier: urn:adorsys:local:pid-provider:keycloak
```

> **Destructive local-start warning:** `start` stops a detected local Keycloak process and runs Docker Compose down with
> volume removal for the upstream deployment. Do not point this runner at a Keycloak process or database volume
> containing data you need to keep. Use `configure` when the intended Keycloak instance is already running and only
> the LoTE/Terraform configuration needs refreshing.

### Faster reconfiguration

When Keycloak is already running and only Terraform or the LoTE needs refreshing:

```bash
./scripts/local-mdoc/local-mdoc-env.sh configure
```

To regenerate/restart only the signed LoTE:

```bash
./scripts/local-mdoc/local-mdoc-env.sh refresh-lote
```

To rerun public readiness checks:

```bash
./scripts/local-mdoc/local-mdoc-env.sh verify
```

The subcommands intentionally have different scopes:

| Command | What it changes | When to use it |
| --- | --- | --- |
| `start` | Rebuilds the plugin, recreates the local DB, starts Keycloak, starts the LoTE server, applies Terraform | First start or a completely clean end-to-end run |
| `configure` | Regenerates/restarts the LoTE server and reapplies Terraform; it does not rebuild or restart Keycloak | Realm, profile, scope, user-grant, key, or LoTE configuration changed |
| `refresh-lote` | Regenerates the signed LoTE and restarts only its HTTPS server | Test LoTE contents or the issuer certificate changed |
| `verify` | Performs read-only health checks | Confirm the LoTE and issuer metadata are reachable |
| `stop` | Stops the test LoTE server and delegates Keycloak/database shutdown to the wrapper | End the local session |

## What Terraform configures

### Selective scope provisioning (`credentials.enabled`)

Terraform uses `var.enabled_scope_names` (populated automatically by the runner and wrapper from `credentials.enabled` in `config-override.yaml`):

- **Scope filtering**: Scans `infrastructure/terraform/jsons/scopes/*.json` and filters them against `var.enabled_scope_names`. Only the selected scopes are registered as Keycloak client scopes. If `credentials.enabled` is omitted or empty, all available scopes in `jsons/scopes/` are installed.
- **Stale-scope pruning**: With an explicit allowlist, previously installed OID4VC scopes that are no longer selected
  are removed from the realm. This keeps issuer metadata aligned with `credentials.enabled` across repeated applies.
- **Client association**: The enabled scopes are added as optional client scopes to `oid4vc-demo-public` and `openid4vc-rest-api`.
- **Conditional user grants**: Verifiable credential grants (e.g., `PIDCredential` for user `francis`) are only created when the respective scope is present in `local.configured_scope_names`. If disabled, unnecessary user grants are skipped.

These are separate controls. A realm credential scope publishes the credential configuration. A client association
allows the client to participate in issuance for that scope. A per-user grant says that a particular user is entitled
to receive that credential. Creating a QR offer checks the realm configuration and user grant; the final credential
request also checks the originating client's optional scopes.

### Issuance

The `PIDCredential` client scope configures:

```text
format:                         mso_mdoc
doctype:                        eu.europa.ec.eudi.pid.1
namespace:                      eu.europa.ec.eudi.pid.1
credential signing algorithm:  ES256 / COSE -7
holder binding:                 cose_key
proof type:                     jwt
```

The configuration name now matches its content: this is an EU PID-shaped mDoc whose document type and namespace are
`eu.europa.ec.eudi.pid.1`. It is not an ISO mobile driving licence; a real mDL profile would use its own ISO mDL
document type and claims.

Its protocol mappers produce:

- `personal_administrative_number` from the Keycloak user's immutable internal `id`;
- `given_name` from `firstName`;
- `family_name` from `lastName`; and
- `issuing_authority` as a display/data claim.

`issuing_authority` is not used as the cryptographic issuer identity. The verifier identity comes from the LoTE
provider entry whose service certificate validated `issuerAuth`.

Keycloak main also requires an explicit per-user grant before a credential can be offered. Terraform creates the
`PIDCredential` client scope and then calls the user VC administration endpoint to create:

```text
francis -> PIDCredential
```

The grant stores a snapshot of the user's mapped attributes. Merely publishing the client scope in issuer metadata is
not sufficient; without the grant, `create-credential-offer` returns `User 'francis' does not have verifiable
credential 'PIDCredential'`.

The ES256 Java-keystore component points Keycloak at the same key/certificate whose public certificate is placed under
the local provider's `ServiceDigitalIdentity` in the LoTE. Keycloak main then embeds its certificate chain in mDoc
`issuerAuth` when producing the issuer-signed document.

### Why the plugin runs on both Keycloak 26.7 and Keycloak main

The plugin Maven build currently compiles against Keycloak 26.7, while this POC deliberately loads the resulting JAR
into Keycloak `999.0.0-SNAPSHOT`. A removed internal constructor previously caused this runtime failure after a wallet
presentation had already been verified:

```text
java.lang.NoSuchMethodError: OAuth2Code.<init>(String, int, String, String, String)
```

Keycloak 26.7 exposes that five-argument constructor, but Keycloak main uses a newer constructor that also carries the
client UUID and other authorization-code state. `AuthorizationResponseService.produceAuthorizationCode()` now creates
the serialized code map and calls `OAuth2Code.deserializeCode(Map)` instead. That static method exists with the same
signature in both versions. The map includes the client UUID, expiration, nonce, scope, user-session ID, redirect URI,
and PKCE challenge information before `OAuth2CodeParser.persistCode()` stores the one-time code.

This is why the same plugin JAR can finish login on Keycloak main without being compiled directly against an unstable
constructor. The authorization-code integration suite also passes against Keycloak 26.7, while the successful Paradym
login exercises the Keycloak-main runtime path.

### Enable SD-JWT alongside mDoc

The current local override enables only `PIDCredential`. To expose the self-issued SD-JWT configuration in the
same environment, change it to:

```yaml
credentials:
  enabled: "IdentityCredential,PIDCredential"
```

Then run `configure` if the required Keycloak features are already active, or `start` for a clean rebuild. The
`IdentityCredential` VCT matches the default `local_sdjwt_vct` used by the `local-sdjwt-login` profile.

### Verification

Terraform stores two OID4VP profiles in the `oid4vp-authenticator` execution:

```json
{
  "id": "local-mdoc-login",
  "credentials": [{
    "id": "identity-mdoc",
    "format": "mso_mdoc",
    "credentialTypes": ["eu.europa.ec.eudi.pid.1"],
    "role": "primary",
    "identitySource": "credential",
    "subjectClaim": "eu.europa.ec.eudi.pid.1/personal_administrative_number",
    "trust": [{
      "type": "eudi_pid_trust_list",
      "trustListUrl": "https://localhost:9443/pid-providers.jwt",
      "serviceType": "http://uri.etsi.org/19602/SvcType/PID/Issuance",
      "issuer": "urn:adorsys:local:pid-provider:keycloak"
    }]
  }]
}
```

The signing-certificate value is also stored in that trust policy but is omitted above for readability. It pins the
public certificate used to validate the LoTE JWS; it is not the mDoc issuer certificate.

## Inspect the running configuration

Issuer metadata:

```bash
curl -ksSf \
  https://localhost:10443/realms/oid4vc-vci/.well-known/openid-credential-issuer \
  | jq '.credential_configurations_supported.PIDCredential'
```

The canonical Keycloak-main discovery URL is also available at:

```text
https://localhost:10443/.well-known/openid-credential-issuer/realms/oid4vc-vci
```

Authorization-server metadata:

```bash
curl -ksSf \
  https://localhost:10443/realms/oid4vc-vci/.well-known/openid-configuration \
  | jq '{issuer, authorization_endpoint, token_endpoint}'
```

The signed test LoTE:

```bash
curl -ksSf https://localhost:9443/pid-providers.jwt
```

Runtime logs:

```bash
tail -f keycloak-oauth-sig/oid4vci-deployment/target/keycloak.log
tail -f target/local-mdoc/lote-server.log
```

## Issue the mDoc into a wallet

Use a wallet supporting OpenID4VCI mDoc issuance and able to trust/reach the local HTTPS server.

1. Configure/import this Credential Issuer in the wallet:

   ```text
   https://localhost:10443/realms/oid4vc-vci
   ```

2. Select credential configuration ID:

   ```text
   PIDCredential
   ```

3. Follow the wallet's authorization-code flow.
4. Sign in to Keycloak as `francis`, using `initial_password` from `secrets-local.tfvars`.
5. Approve issuance.
6. Inspect the received credential and confirm:

   ```text
   format / document: mso_mdoc / eu.europa.ec.eudi.pid.1
   namespace:         eu.europa.ec.eudi.pid.1
   identity element:  personal_administrative_number
   ```

The identity element is the Keycloak user's internal UUID, not the username. This is intentional and is why username
fallback is unnecessary.

### Wallet networking and TLS

`localhost` means the machine on which the wallet runs. A physical phone or emulator will not normally resolve it to
the development host. Use an HTTPS hostname or tunnel reachable by the wallet, then update all issuer-facing URLs
consistently. The wallet must also trust the local development TLS certificate. Do not disable certificate validation
in a production wallet/verifier.

The LoTE URL is fetched by Keycloak itself, so it may remain host-local when only the wallet is remote. However, any
issuer or OID4VP `request_uri` placed into a wallet request must be reachable from that wallet.

## Log in with the issued mDoc

The normal OIDC login page uses the `keycloak.v2+oid4vp` theme and exposes the credential-login option. For a direct
API-driven test, create a PKCE-bound OpenID4VP request for the mDoc profile:

```bash
verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=')"
challenge="$(printf '%s' "$verifier" \
  | openssl dgst -binary -sha256 \
  | openssl base64 -A \
  | tr '+/' '-_' \
  | tr -d '=')"

curl -ksSfG \
  'https://localhost:10443/realms/oid4vc-vci/oid4vp-auth/request' \
  --data-urlencode 'client_id=oid4vc-demo-public' \
  --data-urlencode 'profile_id=local-mdoc-login' \
  --data-urlencode "code_challenge=$challenge" \
  --data-urlencode 'code_challenge_method=S256' \
  | tee /tmp/local-mdoc-auth-request.json
```

The response contains `authorization_request` and `transaction_id`. Open/scan `authorization_request` in the wallet,
select the issued mDoc, and approve presentation. The generated request currently uses the `haip-vp` scheme.

Poll the transaction:

```bash
transaction_id="$(jq -r .transaction_id /tmp/local-mdoc-auth-request.json)"
curl -ksSf \
  "https://localhost:10443/realms/oid4vc-vci/oid4vp-auth/status/$transaction_id" \
  | jq
```

On success, redeem the PKCE-bound result using the same verifier:

```bash
curl -ksSf \
  -X POST 'https://localhost:10443/realms/oid4vc-vci/oid4vp-auth/code' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "transaction_id=$transaction_id" \
  --data-urlencode "code_verifier=$verifier" \
  | jq
```

During presentation, Keycloak performs mDoc device authentication/session-transcript checks, validates `issuerAuth`,
resolves the configured LoTE provider, enforces its identifier, reads the UUID claim, and only then resolves the user.
A credential with the same UUID claim but signed under another LoTE provider entry is rejected before user login.

## How the test LoTE server works

### Why a LoTE is needed

Validating an mDoc signature tells the verifier which certificate signed the Mobile Security Object. It does not, by
itself, give that signer the application-level identity `urn:adorsys:local:pid-provider:keycloak`. The LoTE supplies
that missing, issuer-specific association:

```text
provider identifier
  -> PID/Issuance service
     -> certificate allowed to sign that provider's mDocs
```

The verifier first selects the configured provider entry and then uses only certificates belonging to that entry. It
does not flatten every certificate in the LoTE into one shared trust pool. Consequently, a valid mDoc from another
provider in the same LoTE cannot satisfy this profile merely because both providers participate in the same trust
framework.

### Where its configuration comes from

The test service is assembled from four sources:

| Value | Source | Purpose |
| --- | --- | --- |
| `urn:adorsys:local:pid-provider:keycloak` | `provider_id` in `local-mdoc-env.sh` | Stable identifier of the single test PID Provider |
| Keycloak issuer keystore, password, and ES256 alias | Values resolved by the upstream `helper.sh` | Supplies the certificate that Keycloak uses for mDoc `issuerAuth` |
| LoTE signing key and certificate | Generated under `target/local-mdoc/` by `generate-test-lote.sh` | Signs the LoTE JWS so its contents cannot be changed unnoticed |
| HTTPS certificate and private key | `SSL_SERVER_CERT` and `SSL_SERVER_KEY` resolved by `helper.sh` | Protects transport to `https://localhost:9443` |

`local-mdoc-env.sh` passes the issuer keystore details and provider identifier into `generate-test-lote.sh`. It also
exports the generated LoTE URL, LoTE verification certificate, and provider identifier as Terraform variables. This
keeps the generated trust document and the verifier profile synchronized automatically.

### The three certificates are not interchangeable

| Certificate | Checked by | What it proves |
| --- | --- | --- |
| HTTPS server certificate | Keycloak's HTTP client | The response came through the expected TLS endpoint; Keycloak trusts it through `--truststore-paths` |
| LoTE signing certificate | `EudiTrustListJwtVerifier` in the plugin | The downloaded JWS was signed by the locally pinned LoTE authority |
| mDoc issuer certificate | mDoc verification against the selected LoTE provider service | The presented mDoc was signed by the certificate associated with the configured PID Provider |

Pinning only the LoTE signing certificate would prove that the list is authentic, but not which provider issued the
mDoc. Trusting only the mDoc certificate would lose the provider identifier needed for the `(issuer, subject)` login
identity. Both checks are required.

### What `generate-test-lote.sh` does

On its first run the generator creates a self-signed RSA-3072 development certificate and private key for the LoTE
signer. Later runs reuse them so the certificate pinned in Terraform remains stable. Each run then:

1. Converts the LoTE signing certificate to DER.
2. Exports the ES256 certificate identified by `KEYSTORE_ALIASES_ECDSA_KEY` from Keycloak's PKCS#12 issuer keystore.
3. Creates an ETSI TS 119 602-shaped JSON payload containing one PID Provider and one `PID/Issuance` service.
4. Places the exported Keycloak issuer certificate in that service's `ServiceDigitalIdentity`.
5. Creates a compact JWS with `typ=trustlist+jwt`, `alg=RS256`, `sigT`, and the LoTE signing certificate in `x5c`.
6. Signs `base64url(header) + "." + base64url(payload)` and writes `pid-providers.jwt`.

The payload has an issue time one minute in the past and a `NextUpdate` 30 days in the future. The signing certificate
is valid for ten years, but both durations are test-fixture choices rather than production lifecycle policy.

### What `serve-test-lote.py` does

The server is intentionally small: it is Python's threaded static-file HTTP server wrapped in TLS. It binds to
`0.0.0.0:9443` and serves files from `target/local-mdoc/`. The runner records its PID and log output so it can be
restarted and stopped predictably. The important endpoint is:

```text
https://localhost:9443/pid-providers.jwt
```

The server does not generate trust data, validate credentials, or issue credentials. It only makes the already signed
JWS downloadable. Cryptographic acceptance happens inside the OID4VP plugin.

### Generated LoTE structure

The generated payload follows the ETSI TS 119 602 JSON hierarchy used for PID Provider lists:

```text
LoTE
├── ListAndSchemeInformation
│   └── LoTEType = .../EUPIDProvidersList
└── TrustedEntitiesList[]
    └── TrustedEntityInformation
        ├── TETradeName[] = urn:adorsys:local:pid-provider:keycloak
        └── TrustedEntityServices[]
            └── ServiceInformation
                ├── ServiceTypeIdentifier = .../PID/Issuance
                └── ServiceDigitalIdentity
                    └── X509Certificates[] = mDoc issuer certificate
```

The compact JWS protected header contains `alg`, `x5c`, and `sigT`. The local plugin additionally expects
`typ=trustlist+jwt`. The LoTE signing certificate is passed independently to Terraform and compared by fingerprint
before the JWS signature is accepted.

### Verification sequence during login

When the wallet presents the issued mDoc, the plugin performs the following trust-list work:

1. Download `pid-providers.jwt` from the configured `trustListUrl`.
2. Compare the JWS `x5c` signer certificate with the independently configured `trustListSigningCertificate`.
3. Verify the JWS signature, validate the list timestamps structurally, and reject the list after `NextUpdate`.
4. Find the entity whose registration identifier equals the configured `issuer`.
5. Inside only that entity, select the configured `PID/Issuance` service.
6. Extract only that service's certificate identities.
7. Validate the mDoc `issuerAuth` using those certificates.
8. Return the matched entity identifier as the verified credential issuer.
9. Enforce that issuer together with the configured subject claim before resolving the Keycloak user.

This is a standards-shaped interoperability fixture, not a production trust service. The plugin parses and validates
the security-relevant ETSI subset it consumes; it is not a complete ETSI schema/JAdES conformance validator. A
production deployment must use the governing framework's official, authenticated LoTE distribution and certificate
lifecycle rules.

The plugin caches a verified snapshot for up to 15 minutes, never beyond the LoTE's `NextUpdate`. Regenerating the file
at the same URL does not necessarily invalidate an already cached snapshot immediately. For an immediate
issuer-certificate rotation test, restart Keycloak after `refresh-lote` or wait for the cache entry to expire.

## Stop the environment

```bash
./scripts/local-mdoc/local-mdoc-env.sh stop
```

This stops the local LoTE process and delegates Keycloak/database cleanup to the deployment wrapper.

## Troubleshooting

### Keycloak main changed

Keycloak source is cloned and built inside `keycloak-oauth-sig/oid4vci-deployment/target/keycloak_main`. To rebuild Keycloak after remote changes, delete `keycloak-oauth-sig/oid4vci-deployment/target/keycloak_main/quarkus/dist/target/keycloak-999.0.0-SNAPSHOT.tar.gz` or run `git -C keycloak-oauth-sig/oid4vci-deployment/target/keycloak_main pull`.

### Port already in use

Check the isolated ports:

```bash
ss -ltnp | grep -E ':(10443|15433|9443)\b'
```

Change both the override and `local_keycloak_url` in the runner if `10443` is needed by another service. Change
`database.exposed_port` for a PostgreSQL collision.

### `Expiry.accessing(...)` Caffeine linkage error

This means another provider JAR bundled a Caffeine version incompatible with Keycloak main. The local runner sets
`OID4VP_ONLY=true` so this POC loads only the OID4VP provider. It also clean-builds the provider to prevent stale shaded
classes from leaking into the JAR.

### `OAuth2Code.<init>(...)` `NoSuchMethodError`

This means an older plugin JAR that still calls Keycloak 26.7's five-argument `OAuth2Code` constructor was loaded into
Keycloak main. The current plugin uses the cross-version `OAuth2Code.deserializeCode(Map)` path. Run `start` to
clean-build and restage the plugin, then confirm there is only one OID4VP provider JAR in the prepared Keycloak
distribution.

### Realm already exists during the first Terraform apply

Creating the managed realm also invokes OID4VP flow migration. If the provider retries and receives `409`, the runner
adopts the successfully created realm into its isolated state and resumes the declarative apply.

### Wallet cannot fetch the request or issuer metadata

Replace `localhost` with a host/tunnel reachable by the wallet and use a certificate the wallet trusts. Keep issuer,
authorization-server, client redirect, and request-object URLs consistent; issuer identifiers are exact strings.

### LoTE validation fails

Check all four distinct values:

- `trustListSigningCertificate`: pins the LoTE signer;
- `trustListUrl`: locates the signed LoTE;
- `issuer`: selects one `TrustedEntityInformation` provider;
- `serviceType`: selects that provider's PID issuance service and certificates.

Do not replace the provider identifier with the IACA/trust-anchor name. A shared trust anchor can certify multiple PID
Providers and therefore is not sufficiently issuer-specific for the OpenID4VP identity binding.

### Credential-offer endpoint returns `invalid_client`

Confirm the startup log includes both `oid4vc-vci-rest-credential-offer` and `oid4vc-vci-preauth-code`. The local
override must set `keycloak.enable_rest_credential_offer` and `keycloak.enable_preauth_code` to `true`; both are
startup features and require a Keycloak restart after changing them.

### User does not have `PIDCredential`

This means the credential scope exists, but the user-specific verifiable-credential grant is missing. Reapply the
local Terraform configuration without rebuilding Keycloak:

```bash
./scripts/local-mdoc/local-mdoc-env.sh configure
```

The configuration creates the grant idempotently through `/admin/realms/oid4vc-vci/users/{id}/vc/credentials`.

### `No client scopes found for credential configuration 'PIDCredential'`

In the pre-authorized flow, Keycloak may first search only the credential scopes active in the newly created client
session. Because `PIDCredential` is assigned as an optional scope and is carried by the credential offer rather
than an OAuth `scope` parameter, that first search can log this warning. Keycloak main then has a pre-authorized-flow
fallback to the realm credential scopes.

Treat the warning as fatal only when it is followed by a credential/token error. The local Terraform state should list
`PIDCredential` in the optional scopes for `oid4vc-demo-public`; `configure` reapplies that association. Creating
a QR code proves that the realm credential configuration and user grant were found, but QR creation and final
credential issuance are separate checks.
