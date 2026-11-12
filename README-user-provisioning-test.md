# Local OID4VP user-provisioning test

This guide starts the local Keycloak setup for testing two OID4VP profiles:

- `keycloak-issued` authenticates with an SD-JWT credential issued by this Keycloak realm. It identifies the user with the credential's `sub` claim.
- `german-pid-import` authenticates with the German PID mDoc and imports an unknown user through the hidden `oid4vp-import` identity provider.

## Manual setup

Complete these steps once before running the setup script.

### 1. Build and install the plugin

Build the plugin from the user-import feature branch, then copy its JAR into this repository's `providers/` directory. Keep exactly one `keycloak-oid4vp-plugin-*.jar` there; remove the older plugin JAR.

```bash
cd ~/adorsys_dev/keycloak-oid4vp-plugin
git switch feat/167-user-import-stacked
mvn clean package

cp target/keycloak-oid4vp-plugin-999.0.0-SNAPSHOT.jar \
  ~/adorsys_dev/keycloak-ssi-deployment/providers/
```

The setup script checks that exactly one plugin JAR is present before starting Keycloak.

### 2. Configure the public HTTPS URL

Set `keycloak_url` in `infrastructure/terraform/secrets-user-provisioning-test.tfvars` to the HTTPS URL of your ngrok tunnel. The tunnel must forward to local Keycloak on port `8443` and stay running while you use the wallet. If ngrok assigns a different URL, update `keycloak_url` before running the script.

For example, start a tunnel to the local HTTPS listener with:

```bash
ngrok http https://0.0.0.0:8443 --log=stdout
```

The URL in the tfvars file must be reachable from this machine and from the phone wallet. Do not put ngrok credentials in the tfvars file.

If you use the local `keycloak-oid4vc-mock-fe` frontend, set its `VITE_KEYCLOAK_URL` in that repository's `.env` to the same URL as `keycloak_url` in the test tfvars. Restart the frontend dev server after changing `.env`. The frontend's redirect URL must also be listed under `oid4vc_demo_public_valid_redirect_uris` in the test tfvars.

The test tfvars file is local and Git-ignored because it contains environment settings and secrets. If it does not exist, the script copies `infrastructure/terraform/secrets-local.tfvars` to create it, then enables the user-provisioning test profiles. Review the copy and keep the ngrok URL there.

## Start and provision the test environment

From the root of `keycloak-ssi-deployment`, run:

```bash
./scripts/user-provisioning-test.sh up
```

Terraform will show its plan and ask for confirmation before applying it. Review the changes and enter `yes` to continue.

## What the script does

The `up` command performs these steps:

1. Checks for the required tools, test tfvars file, and exactly one plugin JAR.
2. Starts Keycloak 26.8.2 with `ec2_files` as the Java keystore root. The PDI keystore is stored under the realm-specific directory `ec2_files/oid4vc-vci/oid4vc-ecdsa-only.sandbox-test-pdi.p12`; then the script waits for Keycloak's local HTTPS endpoint to respond.
3. Checks that the ngrok URL in the test tfvars can reach Keycloak. Terraform admin API calls use `https://localhost:8443`; the public ngrok URL remains configured for wallet-facing requests and links.
4. Downloads the German PID sandbox trust-list signing certificate, checks that it is a valid X.509 certificate, and caches it locally in the format the profile expects.
5. Ensures `infrastructure/terraform/backend_override.tf` exists, using `backend_override.tf.example` if needed. Terraform then uses the local backend at `infrastructure/terraform/.local-state/terraform.tfstate`; its plugin working directory is isolated under `.terraform-user-provisioning-test/`.
6. Runs `terraform init` and applies the test tfvars to the local Keycloak realm. This configures the two profiles, enables unknown-user import, creates or updates the hidden `oid4vp-import` identity provider, and configures the PID name and birth-date mappers.
7. Prints a request link for each profile.

The script does not provision AWS resources. The Terraform configuration applies to the local Keycloak instance using the local state backend.

## Use the profiles

When the frontend starts a normal OIDC login for `oid4vc-demo-public`, the Keycloak login page should show two wallet buttons, one for each profile. Click `Keycloak credential` or `German PID`; the plugin's v2 login theme starts the matching OID4VP request and shows the wallet handoff. You do not need to choose a profile from a separate link.

The `up` command also prints direct request links for troubleshooting or testing without the frontend:

- `profile_id=keycloak-issued` for a credential issued by this Keycloak realm.
- `profile_id=german-pid-import` for the German PID mDoc.

If the wallet buttons do not appear, check that the realm login theme is `keycloak.v2+oid4vp`, the frontend uses the same `VITE_KEYCLOAK_URL` as the test tfvars, and its redirect URL is allowed on the `oid4vc-demo-public` client. Also check Keycloak logs for profile validation errors.

The German PID profile pins its trust policy to the sandbox provider `Bundesdruckerei GmbH DEMO PID-Provider`. German PID does not provide a unique person identifier claim. This isolated, single-wallet test uses `family_name` as its federated subject, so two holders with the same family name could resolve to the same imported identity. Do not use this identity choice for multiple holders or production.

## Other script commands

Run these from the repository root:

```bash
./scripts/user-provisioning-test.sh plan   # Show the Terraform plan without applying it
./scripts/user-provisioning-test.sh apply  # Apply the test configuration
./scripts/user-provisioning-test.sh links  # Print both profile request links
./scripts/user-provisioning-test.sh stop   # Stop Keycloak and preserve its database
```
