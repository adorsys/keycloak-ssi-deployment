# How the OID4VP Keycloak plugin authenticates a user

This guide explains the behavior of the `remove-tmp-username-lookup` branch in
`/home/adorsys/adorsys_dev/keycloak-oid4vp-plugin`. It focuses on the changes made for issue #166: stable subject-based
user lookup, issuer-aware mDoc verification, provider-scoped EUDI trust lists, SD-JWT trust behavior, and compatibility
with Keycloak main.

For the runnable local PID mDoc environment, commands, Terraform, and test LoTE server, see
[`LOCAL_MDOC_ISSUANCE_AND_LOGIN.md`](./LOCAL_MDOC_ISSUANCE_AND_LOGIN.md).

## The short version

The plugin does not issue the credential and does not control the wallet. It is the verifier inside Keycloak.

```text
Keycloak asks for a credential
          |
          v
Wallet presents an SD-JWT or mDoc
          |
          v
Plugin verifies the credential, holder binding, claims, and issuer trust
          |
          v
Plugin reads subjectClaim and resolves that exact Keycloak user ID
          |
          v
Optional binding rules compare other claims with the user or primary credential
          |
          v
Keycloak completes the normal login and returns an authorization code
```

For a credential-based primary login, the security identity is conceptually:

```text
(verified credential issuer, configured subject claim)
```

The subject value selects the Keycloak user. The verified issuer prevents an equally named subject from an unrelated
issuer from being trusted by the same profile.

## The configuration model

An authentication profile says what the wallet must present. A simplified PID mDoc profile looks like this:

```json
{
  "id": "local-mdoc-login",
  "displayCta": { "en": "Sign in with local PID mDoc" },
  "credentials": [{
    "id": "identity-mdoc",
    "role": "primary",
    "identitySource": "credential",
    "format": "mso_mdoc",
    "credentialTypes": ["eu.europa.ec.eudi.pid.1"],
    "subjectClaim": "eu.europa.ec.eudi.pid.1/personal_administrative_number",
    "claims": [
      "eu.europa.ec.eudi.pid.1/personal_administrative_number",
      "eu.europa.ec.eudi.pid.1/given_name",
      "eu.europa.ec.eudi.pid.1/family_name"
    ],
    "trust": [{
      "type": "eudi_pid_trust_list",
      "trustListUrl": "https://localhost:9443/pid-providers.jwt",
      "trustListSigningCertificate": "<base64-DER-LoTE-signing-certificate>",
      "serviceType": "http://uri.etsi.org/19602/SvcType/PID/Issuance",
      "issuer": "urn:adorsys:local:pid-provider:keycloak"
    }]
  }]
}
```

The important fields are:

| Field | Meaning |
| --- | --- |
| `role: primary` | This credential determines which Keycloak user is logging in |
| `identitySource: credential` | Read identity from the credential instead of an existing issuance session |
| `format` | Select the SD-JWT or mDoc verifier |
| `credentialTypes` | Allowed SD-JWT `vct` values or the required mDoc `docType` |
| `subjectClaim` | Claim containing the immutable Keycloak user ID |
| `claims` | Claims the wallet is asked to disclose; it must include `subjectClaim` for credential identity |
| `trust` | Rules that decide which credential issuers are accepted |

For mDoc, claim references and `subjectClaim` must use `namespace/element`, because the same element name may occur in
multiple namespaces.

## The complete login flow

### 1. Keycloak creates the wallet request

`AuthorizationRequestService` selects the configured profile and turns its credential requirements into a DCQL query.
It adds the nonce, response URI, response mode, client identifier, requested claims, and verifier metadata, then signs
the request object. The browser displays or opens the resulting wallet link.

With `direct_post`, the wallet posts ordinary OpenID4VP form fields. With `direct_post.jwt`, it posts an encrypted JWE
in the `response` field and the plugin decrypts it using the ephemeral response key advertised in the request.

### 2. The wallet returns presentations by credential ID

The response processing code validates the transaction state and associates each presented token with the credential
ID from the DCQL request. This matters when one profile asks for a primary credential plus supporting credentials.

### 3. The plugin verifies the primary credential first

`OID4VPAuthenticator` chooses a format-specific `CredentialVerifier`:

- `SdJwtCredentialVerifier` for `dc+sd-jwt`;
- `MdocCredentialVerifier` for `mso_mdoc`.

The verifier returns a `VerifiedCredential` containing two things:

```text
issuer: the issuer identity established by the selected trust mechanism
claims: the cryptographically verified disclosed claims
```

The orchestrator never uses unverified token data for user lookup.

### 4. Format-specific security checks run

For SD-JWT, the plugin verifies:

- the issuer-signed JWT signature;
- the configured `vct` and required disclosed claims;
- time claims according to verifier configuration;
- the Key Binding JWT, nonce, audience, and holder key when holder binding is required;
- referenced token status when revocation checking is enabled; and
- transaction-data hashes when transaction data was requested.

For mDoc, the plugin verifies:

- the `issuerAuth` COSE signature and its X.509 path using the configured trust policy;
- MSO digest integrity, validity information, and document type;
- device authentication, session transcript, verifier nonce, wallet-generated nonce, and device key binding;
- requested namespace-qualified claims;
- referenced token status when enabled; and
- transaction-data hashes and their MSO key authorization when requested.

### 5. Issuer enforcement happens before user lookup

For the primary PID mDoc trust-list flow, `TrustedProviderResolver` selects exactly one configured provider from the
signed LoTE and gives `MdocCredentialVerifier` only that provider's PID issuance certificates. After successful mDoc
verification, the verifier returns that provider identifier. `OID4VPAuthenticator` checks it again against the profile
as defense in depth.

This is the important ordering:

```text
verify LoTE -> select configured provider -> verify mDoc -> establish issuer -> read subject -> find user
```

The plugin never looks up the user first and then decides whether the issuer was acceptable.

### 6. The subject claim resolves the Keycloak user

The plugin reads the configured `subjectClaim` from the verified primary claims and calls Keycloak's user provider by
internal user ID.

There is no username fallback and no automatic issuer-to-user enrollment:

```text
subject claim missing                          -> reject
subject does not identify an existing user     -> reject
resolved user is disabled                      -> reject
issuer verification or issuer match fails      -> reject
```

Username can still appear in an explicit binding rule, for example to compare a disclosed claim with the already
resolved user's username. It is validation data in that case, not an alternative way to locate the account.

### 7. Supporting credentials are verified and bound

After the primary credential identifies the user, every presented supporting credential is independently verified.
Binding rules can then require:

- a supporting claim to equal a claim from the primary credential; or
- a supporting claim to equal an attribute of the resolved Keycloak user.

The default comparator is an exact match. Built-in user-attribute aliases include `given_name`/`firstName`,
`family_name`/`lastName`, and `username`/`preferred_username`.

### 8. Keycloak completes login

After all required credentials and bindings pass, the authenticator attaches the resolved `UserModel` to the Keycloak
authentication flow. `AuthorizationResponseService` creates the one-time OAuth authorization code and Keycloak resumes
the ordinary OIDC login.

The branch now constructs `OAuth2Code` through `OAuth2Code.deserializeCode(Map)`. That method is present in both
Keycloak 26.7 and Keycloak main, avoiding the removed five-argument-constructor `NoSuchMethodError`. Redirect URI and
PKCE challenge information are preserved in the serialized code data.

## Trust policies in simple terms

Trust answers one question: "Which issuer keys am I willing to accept for this requested credential?"

| Policy | SD-JWT | mDoc | Where keys come from | Issuer behavior |
| --- | --- | --- | --- | --- |
| `self` | Yes | No | Enabled signing keys of the current Keycloak realm | Signed `iss` must be the current realm issuer under the normal self profile |
| `x5c` | No direct SD-JWT policy support | Yes | Certificates pinned in `anchors` | Certificate trust is static; optional `issuer` is configuration metadata rather than an identifier discovered from the certificate |
| `eudi_pid_trust_list` | Yes | Yes | Provider/service certificates from a signed LoTE | The configured `issuer` selects one provider, and verification is scoped to that provider's certificates |

### `self`: accept credentials from this Keycloak realm

Example:

```json
{ "type": "self" }
```

This is the simplest SD-JWT setup when Keycloak issued the credential itself. `SelfTrustedSdJwtIssuer` selects enabled
realm signing keys, optionally narrows them using the JWT `kid`, and the SD-JWT requirements check the signed `iss`
against the realm issuer.

Use it when issuer and verifier are the same Keycloak realm. It is intentionally rejected for mDoc.

### `x5c`: pin certificate anchors directly

Example for mDoc:

```json
{
  "type": "x5c",
  "anchors": ["<base64-DER-certificate>"],
  "issuer": "<optional-local-name-for-this-pinned-issuer>"
}
```

The plugin parses the configured anchors at profile load time. During mDoc verification it validates the presented
issuer certificate path against those anchors.

This is useful for a closed test or a small deployment where certificates are known beforehand. Rotation requires a
configuration update, and an anchor alone does not provide a standardized provider registration identifier. For the
OpenID4VP `(issuer, subject)` requirement in a multi-provider PID ecosystem, the EUDI trust-list policy is clearer and
safer because it associates certificates with a named provider entity.

The generic profile model knows the `x5c` policy name, but the SD-JWT resolver does not implement a standalone `x5c`
policy. An SD-JWT containing an `x5c` header is supported through `eudi_pid_trust_list`, where that chain is checked
against the selected provider's LoTE certificates.

### `eudi_pid_trust_list`: resolve a provider from a signed list

Example:

```json
{
  "type": "eudi_pid_trust_list",
  "trustListUrl": "https://trust.example/pid-providers.jwt",
  "trustListSigningCertificate": "<base64-DER-LoTE-signing-certificate>",
  "serviceType": "http://uri.etsi.org/19602/SvcType/PID/Issuance",
  "issuer": "<official-provider-registration-identifier>"
}
```

The values have different jobs:

| Value | Job |
| --- | --- |
| `trustListUrl` | Location from which Keycloak downloads the LoTE; HTTPS is mandatory |
| `trustListSigningCertificate` | Independently pinned certificate used to authenticate the LoTE JWS signer |
| `serviceType` | Selects PID issuance services; it defaults to the ETSI PID issuance URI |
| `issuer` | Selects the exact provider entity whose certificates may validate the credential |

The plugin then:

1. Downloads and trims the compact trust-list JWT.
2. Requires `typ=trustlist+jwt` and a supported signature algorithm.
3. Reads the JWS `x5c` signer certificate and compares its SHA-256 fingerprint with the configured signing
   certificate.
4. Verifies the JWS signature.
5. Requires the PID Providers LoTE type, parses `ListIssueDateTime`/`NextUpdate`, and rejects an expired list.
6. Preserves each `TrustedEntityInformation` entry with its own matching service certificates.
7. Resolves the configured `issuer` to exactly one entity, using `TETradeName` where present and `TEName` only as a
   compatibility fallback.
8. Uses only that entity's matching `PID/Issuance` certificates.

For a primary mDoc login, configuration validation requires exactly one trust-list policy and a nonblank `issuer`.
This prevents ambiguity about which issuer is combined with the subject claim.

For SD-JWT under this policy, the plugin additionally requires the signed JWT `iss` to equal the configured provider
identifier. It then validates the JWT header's `x5c` chain against only that provider's certificates and uses the leaf
certificate to verify the JWT signature. A certificate belonging to Provider B cannot validate a credential claiming
to be from configured Provider A, even when both providers occur in the same signed LoTE.

The verified LoTE snapshot is cached for at most 15 minutes and never beyond `NextUpdate`.

## Primary versus supporting trust-list behavior

A credential-based primary credential creates the login identity, so issuer selection must be unambiguous. The strict
PID mDoc path therefore selects exactly one configured provider before verification.

A supporting credential does not choose the user. The primary credential has already done that, and explicit binding
rules connect the supporting claims to that user. Supporting mDocs may therefore be configured with a wider set of
trusted anchors or trust-list entries when the application genuinely accepts several issuers. Their claims still do
not replace the primary subject used for account lookup.

## Presentation during issuance is different

When `identitySource` is `session`, the user comes from an already authenticated, session-bound issuance flow. The
presented credential does not select a Keycloak account. For that reason:

- `subjectClaim` is not required for account lookup;
- at least one binding rule is mandatory; and
- the credential must be compared with the session user so presenting any valid credential is not enough.

This is separate from normal wallet login, where `identitySource: credential` and `subjectClaim` identify the user.

## What changed on this branch

### Username workaround removed

- Removed `usernameClaim` from credential requirements.
- Removed username-only fallback lookup.
- Removed the post-lookup username mismatch check.
- Kept username available only for explicit `claim_equals_user_attribute` binding rules.

### Verified issuer now travels with verified claims

- Added `VerifiedCredential(issuer, claims)` as the format-verifier result.
- Added `CredentialIdentity(issuer, subject)` to make the intended identity pair explicit.
- SD-JWT obtains issuer from the signed `iss` claim.
- Strict PID mDoc obtains issuer from the selected LoTE provider entry, not from `issuing_authority` display data.

### mDoc trust-list issuer enforcement added

- The LoTE parser preserves provider-to-service-to-certificate structure.
- A primary PID profile must name one provider.
- Only that provider's issuance certificates validate the mDoc.
- The resolved provider identifier is enforced before subject-based user lookup.

### SD-JWT trust-list isolation hardened

- EUDI SD-JWT verification now resolves the configured provider first.
- Its JWT `x5c` chain is checked against that provider's certificates rather than a flattened list containing every
  provider certificate.

### Keycloak-main authorization-code compatibility fixed

- Removed the runtime dependency on the old five-argument `OAuth2Code` constructor.
- Uses the stable map deserializer and includes the new `client_uuid` field understood by Keycloak main.

## Fail-closed behavior

Authentication is rejected when any required step fails, including:

- malformed or missing presentation;
- unknown format or credential ID;
- missing required claims or wrong credential type;
- signature, certificate path, holder binding, nonce, audience, or transaction-data failure;
- untrusted, expired, malformed, ambiguous, or incorrectly signed LoTE;
- configured issuer missing from the LoTE;
- credential signed by a different provider's certificate;
- blank or unknown subject ID;
- disabled Keycloak user; or
- failed primary/supporting binding rule.

The plugin does not trust-on-first-login, does not save the first presented issuer on a user, and does not fall back to
username when subject lookup fails.

## Main code map

| Responsibility | Plugin class |
| --- | --- |
| Build signed OpenID4VP request | `AuthorizationRequestService` |
| Process wallet response and complete login | `AuthorizationResponseService` |
| Orchestrate primary user lookup and supporting bindings | `OID4VPAuthenticator` |
| Verify SD-JWT presentation | `SdJwtCredentialVerifier` |
| Choose SD-JWT trust implementation | `SdJwtTrustedIssuerResolver` |
| Verify mDoc presentation | `MdocCredentialVerifier` |
| Resolve mDoc anchors and provider issuer | `TrustedProviderResolver` |
| Download/cache a signed PID LoTE | `EudiPidTrustListProvider` |
| Authenticate the LoTE JWS | `EudiTrustListJwtVerifier` |
| Preserve entity/service/certificate associations | `EudiTrustListPayloadParser` |
| Validate authentication profile safety | `OID4VPProfileConfig` |
