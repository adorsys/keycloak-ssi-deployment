## Credential Offer Demo (TypeScript + Vite)

This lightweight frontend helps you authenticate the `francis` user in the `oid4vci` realm and request a credential offer from Keycloak’s OID4VCI endpoints.

### 1. Install dependencies

```bash
cd /home/adorsys/keycloak-ssi-deployment/frontend
npm install
```

### 2. Configure environment

Copy `env.example` to `.env.local` (or `.env`) and adjust it to your Keycloak URLs / client configuration:

```
VITE_KEYCLOAK_BASE_URL=https://localhost:8443
VITE_KEYCLOAK_REALM=oid4vci
VITE_KEYCLOAK_CLIENT_ID=oid4vc-demo-public
VITE_CREDENTIAL_CONFIGURATION_ID=IdentityCredential
```

Make sure the `oid4vc-demo-public` client contains the dev server origin (e.g. `http://localhost:5173`) under **Web Origins** and **Redirect URIs**.

### 3. Run the dev server

```bash
npm run dev -- --host
```

Open the printed URL in a browser, log in as `francis`, and click **Get Credential Offer**.

### What the UI does

1. Uses `keycloak-js` to perform PKCE login against `oid4vci`.
2. Calls `GET /realms/{realm}/protocol/oid4vc/credential-offer-uri` with the user access token.
3. Follows the returned credential-offer link and shows the JSON payload directly in the browser.

If anything fails (access token, endpoint errors, etc.), the UI surfaces the error message so you can diagnose configuration issues quickly.

