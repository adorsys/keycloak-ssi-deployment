# German National Wallet external-user import test

This setup tests ticket #167 with the German National Wallet on iOS: a user who does not yet exist in Keycloak presents
a trusted German test PID, the OID4VP plugin verifies it, and only then creates and links a Keycloak user. It extends
the environment in [LOCAL_MDOC_ISSUANCE_AND_LOGIN.md](./LOCAL_MDOC_ISSUANCE_AND_LOGIN.md), so the existing local mDoc
and local SD-JWT profiles remain available as control logins.

## Credential identified from the wallet

The supplied “Digital ID” screenshots show the Erika Mustermann test identity and claims such as issuing/expiry date,
`family_name`, `given_name`, `birth_date`, age-over flags, and scalar resident-address fields. Those labels match the
German PID **mDoc** metadata published by the German demo PID Provider:

| Property | Configured value |
| --- | --- |
| Format | `mso_mdoc` |
| Document type | `eu.europa.ec.eudi.pid.1` |
| Main namespace | `eu.europa.ec.eudi.pid.1` |
| Test profile | `german-wallet-mdoc-import` |
| Test subject claim | `eu.europa.ec.eudi.pid.1/birth_date` |

The wallet source also supports German PID SD-JWT credentials with VCT `urn:eudi:pid:de:1`, but the card title
“Digital ID” alone is not a format indicator. This setup intentionally does not pretend that the same static `x5c`
policy verifies SD-JWT: the plugin's externally issued SD-JWT path requires an EUDI PID trust list and the actual
signed `iss` provider identifier. The existing `local-sdjwt-login` profile remains available to regression-test the
SD-JWT verifier. Add an external German SD-JWT profile only after obtaining its signed issuer identifier and matching
trust-list entry.

## Subject, external ID, and username are different values

The initial version of this setup allowed the plugin's fallback username derivation to turn the configured subject,
`birth_date`, into the username `1964-08-12`. That was technically consistent with the plugin default, but it was a
bad test configuration: a date is not a meaningful Keycloak username.

The corrected setup uses three separate values:

| Value | Purpose | Value in this test |
| --- | --- | --- |
| Credential subject | Stable value selected from the verified credential to identify the person within one issuer | `birth_date` = `1964-08-12` |
| Federated external ID | Opaque Keycloak link key computed by the plugin from the verified issuer namespace and subject | `v1.<sha256(issuer, subject)>` |
| Keycloak username | Local account name, staged through a normal import mapper and checked by Keycloak | `given_name` = `ERIKA` |

The plugin uses its subject-derived username only when no username mapper exists. This setup now explicitly maps the
signed `given_name` claim to Keycloak's `username` field, so the expected username is `ERIKA`, not the date of birth.
The same claim is also mapped to `firstName`; `family_name` is mapped to `lastName`.

The wallet card displays “Erika Mustermann”, but that display string is not shown as a standalone signed claim in the
screenshots. The signed claims shown are `given_name=ERIKA` and `family_name=MUSTERMANN`. The plugin's supported mapper
copies one claim at a time and does not concatenate them into `erika.mustermann`. Creating that username would require
either a signed `preferred_username`-style claim or a separately designed and tested username-template mapper. The
verifier must not derive security-relevant data from an unsigned UI label.

### Why `birth_date` is still the subject in this demo

The claims visible in the supplied credential are:

- issuing country and authority;
- issuance and expiry dates;
- family name, given name, and birth name;
- date and place of birth;
- document type and nationality;
- age-over attestations; and
- resident address fields.

None is a stable unique person identifier. In particular, the screenshots do not show
`personal_administrative_number`, `document_number`, `sub`, or another issuer-defined unique ID. Ticket #167 needs one
configured subject claim to construct the external identity, so this single-Erika interoperability test continues to
use `birth_date`.

That is deliberately **not production-safe**: unrelated people can share a birth date, and `ERIKA` can also collide as
a username. Keycloak rejects such a collision and does not merge accounts, but a production profile must use an
issuer-defined stable unique subject. It should normally also map a unique username or configure the realm to use a
unique email when the credential contains one. Do not promote this test profile unchanged.

## What the setup configures

```text
German National Wallet
  -> presents German PID mDoc
  -> Keycloak OID4VP endpoint
       1. verifies mDoc device/session binding
       2. authenticates the official sandbox PID Provider LoTE with its pinned signer
       3. selects the Bundesdruckerei GmbH PID issuance services
       4. builds and validates issuerAuth x5c against that provider's certificates
       5. assigns the authenticated provider identifier as the verified origin
          Bundesdruckerei GmbH
       6. reads eu.europa.ec.eudi.pid.1/birth_date
       7. resolves the federated link for (verified origin, subject)
       8. imports an unknown user only when no link exists
  -> hidden identity provider oid4vp-import
       -> maps given_name to username
       -> maps given_name to firstName
       -> maps family_name to lastName
       -> stores birth date and issuing country as attributes
  -> target-realm user profile
       -> permits an imported account without email
       -> exposes mapped custom attributes to administrators as read-only fields
```

The credential trust source is the official German sandbox PID Provider LoTE at
`https://bmi.usercontent.opencode.de/eudi-wallet/test-trust-lists/pid-provider.jwt`. The runner independently downloads
the publication's `certificate.pem`, converts it to DER, pins SHA-256
`ee29b8c398635ddca1e5e9bd3670d131d3875cb5423c23f64f981e03d41e8fad`, checks its validity period, and refuses a
changed download. The plugin then verifies the LoTE JWS and selects only the PID issuance certificates belonging to
the configured `Bundesdruckerei GmbH` provider entry.

The similarly named iOS asset `Wallet/Certificates/pidissuerca02_de.der` is not used here. Its current certificate is
`CN=German Registrar`; it authenticates a different trust role and does not build a certification path for the
Bundesdruckerei PID presented in this test. A checksum, LoTE signature, provider-selection, or PKIX failure must be
investigated as a trust-material change, never bypassed.

For a primary mDoc, the configured LoTE provider identifier is also the stable verified issuer namespace. The plugin
hashes that identifier together with the disclosed subject to produce the external federated ID. Changing the provider
identifier later changes account-link identity and requires an explicit link migration.

The hidden identity provider is a mapping and link host only. It cannot perform browser login. It uses `FORCE` sync
mode so subsequent valid presentations refresh mapped values. There is no username lookup fallback: a same-named
local Keycloak user is neither selected nor linked automatically.

## Configuration created by the runner

The runner combines five pieces that must agree:

| Piece | Configuration | Reason |
| --- | --- | --- |
| OID4VP profile | `german-wallet-mdoc-import` requests the German PID mDoc and four claims | Tells the wallet exactly which verified credential and disclosures are required |
| Trust policy | `eudi_pid_trust_list`, pinned LoTE signer, exact `Bundesdruckerei GmbH` provider, PID issuance service type | Authenticates the provider-specific credential signing certificates before identity lookup |
| Authenticator import settings | `importUnknownUsers=true`, `importIdentityProviderAlias=oid4vp-import` | Enables first-login creation and selects the link/mapping host |
| Import provider and mappers | Hidden `oid4vp-plugin-import` provider with `FORCE` sync | Stages Keycloak fields and owns the standard federated identity link |
| Realm user profile | Email-as-username is disabled, email is optional, and unmanaged attributes use `ADMIN_VIEW` | Accepts the fields the German PID can actually supply and makes mapped custom fields visible through management interfaces |

The profile requests only the claims needed for this test:

| Signed mDoc element | Plugin use | Keycloak destination |
| --- | --- | --- |
| `eu.europa.ec.eudi.pid.1/birth_date` | Test-only external subject | `oid4vpBirthDate` |
| `eu.europa.ec.eudi.pid.1/given_name` | Imported username and first name | `username`, `firstName` |
| `eu.europa.ec.eudi.pid.1/family_name` | Imported last name | `lastName` |
| `eu.europa.ec.eudi.pid.1/issuing_country` | Audit/useful profile data | `oid4vpIssuingCountry` |

The other claims visible in the screenshots are intentionally not requested. OpenID4VP should ask for only what the
login/import use case needs.

### Why email is optional in this test realm

Keycloak's default declarative user profile requires `email` for registration. The German PID test credential cannot
satisfy that policy: email is not available from the German eID, so requesting or mapping an empty email would still
fail validation. The runner therefore explicitly disables email-as-username and removes only the email `required`
rule in the `oid4vc-vci` test realm. It keeps the email field and its normal format/length validation for accounts that
do have an email. It does not invent an email, derive one from a name, or bypass user-profile validation.

The runner also sets `unmanagedAttributePolicy` to `ADMIN_VIEW`. This lets administrators inspect
`oid4vpBirthDate` and `oid4vpIssuingCountry` while keeping unmanaged attributes unavailable to ordinary registration
and account-management contexts. Production realms should preferably declare intentional custom attributes in their
user-profile schema, including appropriate permissions, rather than broadly relying on unmanaged attributes.

## How the plugin performs user import

### First presentation

1. The browser or direct API asks for profile `german-wallet-mdoc-import`.
2. The wallet matches the mDoc doctype and asks the holder to approve the requested disclosures.
3. The plugin verifies the OpenID4VP response, mDoc device authentication, session transcript, issuer signature, and
   certificate chain. Nothing is imported before these checks pass.
4. Successful provider-scoped PKIX verification assigns the authenticated LoTE provider identifier as the issuer
   namespace. The plugin reads `birth_date` as the configured subject and computes an opaque, versioned SHA-256
   external ID from `(issuer namespace, subject)`.
5. Keycloak searches only for the federated link `(oid4vp-import, external ID)`. It does not search users by `ERIKA`,
   `MUSTERMANN`, email, or date of birth.
6. If no link exists and import is enabled, the plugin creates an in-memory `BrokeredIdentityContext`. The supported
   claim mappers stage username `ERIKA`, first name `ERIKA`, last name `MUSTERMANN`, birth date, and issuing country.
7. Before writing anything, the plugin evaluates configured claim bindings, rejects username/email collisions, and
   asks Keycloak's `UserProfileProvider` to validate the proposed account fields.
8. In one transaction, it creates the enabled user, copies mapped fields, adds the federated identity link, runs the
   provider/mapper lifecycle hooks, and emits Keycloak's `REGISTER` event with registration method `oid4vp`.
9. If any write or hook fails, the transaction is marked rollback-only so no orphan user or dangling link remains.

### Later presentations

1. The plugin repeats all presentation, holder-binding, signature, chain, and issuer-origin verification.
2. It recomputes the same issuer-qualified external ID.
3. The existing federated link selects the already imported Keycloak user.
4. With `FORCE` sync, mapped fields may be refreshed only after bindings pass. The username is kept as the existing
   linked user's username; relogin does not create another account.

Turning `importUnknownUsers` off later prevents new imports but does not remove existing links or prevent a correctly
linked user from logging in.

### Fail-closed behavior

The plugin refuses import when the credential signature or chain is invalid, the issuer namespace or subject is
missing, the hidden provider is missing/disabled/wrong, a required mapped field violates the realm profile, a username
or unique-email collision exists, or a binding rule fails. A matching local username never causes automatic linking.

## Prerequisites

Follow the repository layout, local secrets, and `config-override.yaml` prerequisites in
[LOCAL_MDOC_ISSUANCE_AND_LOGIN.md](./LOCAL_MDOC_ISSUANCE_AND_LOGIN.md). Also ensure:

- the feature plugin checkout is on `feat/167-user-import-stacked` (or contains the equivalent merged code);
- `curl`, `jq`, `openssl`, and `sha256sum` are installed;
- the iPhone can reach every URL embedded in the OpenID4VP request; and
- the wallet trusts the public HTTPS transport certificate presented for those URLs.

### How the registered verifier identity was reused locally

The stock German wallet validates the relying party **before** it offers a credential for disclosure. A reachable
`request_uri` is therefore not sufficient: the request must also be signed as a verifier that the German sandbox
recognizes. Because a new sandbox registration could not be created for this test, the already registered DATEV
verifier identity from `keycloak-demo.solutions.adorsys.com` was reused for the local Keycloak instance.

This required three matching artifacts from the existing deployment:

| Artifact | Local source | Role in the wallet request |
| --- | --- | --- |
| ES256 private key | `ec2_files/oid4vc-ecdsa-only.p12` | Signs the OpenID4VP Request Object. Possession of this key is what lets the local instance act as the registered verifier. |
| Access Certificate | `oid4vp_access_certificate` in `infrastructure/terraform/secrets-26.6-updates.tfvars` | Placed as the single certificate in the signed Request Object's `x5c` header. The wallet validates it as the verifier/reader certificate. |
| Registration Certificate | `oid4vp_registration_certificate` in the same tfvars file | Sent unchanged as the `registration_cert` entry in `verifier_info`. It describes the registered relying party, purpose, and permitted/requested data context to the wallet. |

The PKCS#12 password is stored separately in `ec2_files/ecdsa_keystore.password`. Place both recovered secret files
in the ignored directory:

```text
ec2_files/oid4vc-ecdsa-only.p12
ec2_files/ecdsa_keystore.password
```

The runner never prints the password or changes the recovered PKCS#12 file. It verifies that alias
`ecdsa_team_key` is a private-key entry whose public-key SHA-256 is
`7a252a19c160ed3c9d7cd53ac8b7c328abd71a8ed004608de7d2d0b7b480f49d`, and verifies that the Access Certificate
contains that same public key. The certificate stored inside the PKCS#12 need not be byte-for-byte identical to the
registered Access Certificate; it is the signing key pair that must match. The script then creates an ignored local
copy under the alias and password expected by the local harness, leaving the recovered EC2 file unchanged.

The script configures `clientIdentifierPrefix=x509_hash`. The plugin consequently constructs:

```text
client_id = x509_hash:<base64url(SHA-256(DER-encoded Access Certificate))>
```

It uses the corresponding private key to sign the Request Object and puts the Access Certificate in the JWS `x5c`
header. The plugin checks that the configured Access Certificate is currently valid and that its public key matches
the active signing key before creating a request. The Registration Certificate JWT is separately placed in
`verifier_info`; it is not a signing key and the two certificate values must not be swapped.

This explains why an Access Certificate whose SAN names `keycloak-demo.solutions.adorsys.com` could still be used
while the local server was exposed through an ngrok hostname. Under `x509_hash`, verifier identity is bound to the
hash of the Access Certificate rather than to the current request hostname. The ngrok URL supplied only the publicly
reachable HTTPS locations for `request_uri` and `response_uri`. Its TLS certificate secured transport to the local
server, but it neither registered the ngrok hostname as a new German-sandbox verifier nor replaced the Access
Certificate.

The resulting flow was:

```text
iPhone wallet
  -> opens request_uri on the temporary ngrok HTTPS origin
  -> downloads the Request Object generated by local Keycloak
  -> validates its signature, Access Certificate, x509_hash client_id,
     and Registration Certificate as the existing DATEV verifier
  -> prompts for and sends the German PID to response_uri through ngrok
  -> local Keycloak independently validates the PID issuer chain through
     the German PID Provider LoTE, then resolves/imports the external user
```

There are therefore two independent trust directions:

1. **Wallet trusts verifier:** private signing key + Access Certificate + Registration Certificate. This is what
   fixed the wallet-side failure that occurred before the disclosure prompt.
2. **Verifier trusts PID issuer:** signed PID Provider LoTE + configured provider identifier + the PID's issuer
   certificate chain. This is what allowed Keycloak to verify the German PID after the holder approved disclosure.

Reusing production or shared sandbox verifier private keys on a workstation is appropriate only for a controlled,
time-limited interoperability test with the key owner's authorization. It duplicates a high-value private key,
causes local requests to represent the registered DATEV party, and couples both deployments to the same certificate
expiry and revocation. Do not commit or distribute these files, do not use this as a production deployment pattern,
and remove the local copies after testing. Prefer a separately registered verifier identity and key for every durable
environment.

Keep both recovered files mode `0600`. Never commit them or expose their contents in logs. The Access Certificate and
Registration Certificate can be deployment configuration, but the PKCS#12 and its password remain secrets. A
certificate without the matching private key cannot produce an accepted signed request.

For a physical iPhone, `localhost` refers to the phone, not this workstation. Use a routable HTTPS hostname or tunnel
with a publicly trusted TLS certificate valid for that hostname, and update the deployment URL consistently. That
transport certificate is separate from the registered Access Certificate used by `x509_hash`. The host-local LoTE
used by the control profile does not need to be exposed to the phone.

## Start the environment

From the deployment repository:

```bash
./scripts/german-wallet-import/german-wallet-import-env.sh start
```

Set `realm_frontend_url` in the ignored `infrastructure/terraform/secrets-local.tfvars` file to the HTTPS origin,
without a path, through which the phone reaches local Keycloak. The current local configuration uses:

```hcl
realm_frontend_url = "https://98d8-2605-59c0-1ee6-f10-cc7a-38b7-d344-5aa5.ngrok-free.app"
```

Update that value whenever a temporary tunnel receives a new hostname. For a one-off override without editing the
file, `OID4VP_PUBLIC_URL=https://current-host.example` remains supported and takes precedence.

`start` is intentionally clean and destructive for the local test database: it stops the current harness instance,
removes its Compose database volume, builds the feature plugin, starts Keycloak main, applies the local control
profiles plus the German PID profile, reconciles the target-realm user profile, installs the hidden import provider
and mappers, and verifies the result.

If the base environment is already running and only its realm configuration needs reconciliation:

```bash
./scripts/german-wallet-import/german-wallet-import-env.sh configure
```

Other lifecycle commands are:

```bash
./scripts/german-wallet-import/german-wallet-import-env.sh verify
./scripts/german-wallet-import/german-wallet-import-env.sh stop
```

The pinned German sandbox LoTE signing certificate remains under `target/german-wallet-import/`; the shared disposable Terraform state and local
LoTE artifacts remain under `target/local-mdoc/`.

## Run the import test

Use the normal OIDC login page and choose **Sign in with German test PID**, or create a direct PKCE-bound request for
the profile:

```bash
verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=')"
challenge="$(printf '%s' "$verifier" | openssl dgst -binary -sha256 \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=')"

curl -ksSfG \
  'https://localhost:10443/realms/oid4vc-vci/oid4vp-auth/request' \
  --data-urlencode 'client_id=oid4vc-demo-public' \
  --data-urlencode 'profile_id=german-wallet-mdoc-import' \
  --data-urlencode "code_challenge=$challenge" \
  --data-urlencode 'code_challenge_method=S256' \
  | tee /tmp/german-wallet-import-request.json
```

Open or scan the returned `authorization_request` in the German National Wallet and approve the PID presentation.
Then poll and redeem exactly as described in the local mDoc guide, using the returned `transaction_id` and the same
PKCE verifier.

On the first successful presentation, expect one enabled Keycloak user with:

- username `ERIKA`;
- first name `ERIKA` (wallet casing may vary);
- last name `MUSTERMANN`;
- attributes `oid4vpBirthDate=1964-08-12` and `oid4vpIssuingCountry=DE`; and
- one federated identity link owned by `oid4vp-import`.

Present the credential a second time. It must resolve the federated link and return the same user rather than creating
another user. A pre-existing local user named `ERIKA` should cause a collision error; it must not restore the old
username fallback.

## What a failure means

| Symptom | Likely cause |
| --- | --- |
| Wallet reports no matching credential | The installed PID may be SD-JWT rather than mDoc, or does not disclose `birth_date` |
| `Certificate chain validation failed` | The selected LoTE provider does not contain a certificate that can validate the presented PID chain, or the provider rotated its issuance PKI and the signed LoTE/configuration is stale |
| `User with presented OID4VP credential is unknown` | Import is disabled, the hidden provider is absent/disabled, or verified-origin resolution failed |
| `error-user-attribute-required` with `inputHint='email'` | The target realm still requires an email that the German PID cannot supply; rerun the harness `configure` command and verify the realm user profile |
| Username collision | A local/imported user already owns `ERIKA`; fallback linking is intentionally forbidden |
| Phone cannot open `request_uri` | The request still contains a host-local URL or an untrusted/mismatched TLS certificate |
| Wallet fails before prompting with `Could not trust certificate chain` | The registered access certificate is absent, the recovered signing key is not active, or the request uses the wrong client-identifier policy |

Never fix a trust failure by switching to `self`, disabling certificate validation, trusting a certificate copied from
an unverified presentation, or mapping by displayed name. First confirm the credential format, inspect the signing
chain/provider, and update the signed LoTE or its independently pinned signing certificate from the official sandbox
publication.

## Files added or extended

```text
GERMAN_WALLET_EXTERNAL_USER_IMPORT.md
scripts/german-wallet-import/german-wallet-import-env.sh
scripts/german-wallet-import/configure-import-provider.sh
scripts/german-wallet-import/configure-realm-user-profile.sh
infrastructure/terraform/main.tf
infrastructure/terraform/variables.tf
infrastructure/terraform/modules/realm/main.tf
infrastructure/terraform/modules/realm/variables.tf
```

For the plugin's broader verification and trust model, see
[OID4VP_PLUGIN_FLOW_AND_TRUST.md](./OID4VP_PLUGIN_FLOW_AND_TRUST.md).

## External references

- [German National Wallet iOS source](https://github.com/german-national-wallet/de-eudi-wallet-ios)
- [German sandbox Access and Registration Certificate usage](https://bmi.usercontent.opencode.de/eudi-wallet/developer-guide/rp/guide/presentation/registrar_certificate_usage/)
- [German sandbox `client_id`, nonce, and state binding](https://bmi.usercontent.opencode.de/eudi-wallet/developer-guide/concepts/binding/client_id_nonce_state/)
- [Wallet document identifiers](https://github.com/german-national-wallet/de-eudi-wallet-ios/blob/main/Modules/logic-core/Sources/Model/DocumentIdentifier.swift)
- [Wallet OpenID4VP and reader-trust configuration](https://github.com/german-national-wallet/de-eudi-wallet-ios/blob/main/Modules/logic-core/Sources/Config/WalletKitConfig.swift)
- [Bundesdruckerei demo PID Provider metadata](https://demo.pid-provider.bundesdruckerei.de/docs/manual.html)
- [German PID reference for relying parties](https://bmi.usercontent.opencode.de/eudi-wallet/developer-guide/resources/pid_reference/)
- [German sandbox PID Provider trust list](https://bmi.usercontent.opencode.de/eudi-wallet/test-trust-lists/)
