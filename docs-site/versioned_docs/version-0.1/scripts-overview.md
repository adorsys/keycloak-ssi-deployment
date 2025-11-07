---
sidebar_position: 2
---

# Scripts Overview

This section provides an overview of the key shell scripts used in the `keycloak-ssi-deployment` project for setting up Keycloak, deploying OID4VCI, and requesting credentials.

## 0.start-kc-oid4vci.sh

This script is responsible for starting the Keycloak server with the OID4VCI (OpenID for Verifiable Credential Issuance) feature enabled.

**Key functionalities:**
-   **Environment Loading:** Sources common environment variables from `load_env.sh`.
-   **Keycloak Shutdown:** Checks for and shuts down any running Keycloak instances to prevent conflicts.
-   **Keycloak Setup:** Executes `setup-kc-oid4vci.sh` to download, unpack, and prepare Keycloak.
-   **Docker Compose Detection:** Determines whether to use `docker compose` or `docker-compose`.
-   **Database Startup:** Starts the PostgreSQL database container using Docker Compose if `KC_DB_OPTS` is not set.
-   **Provider Injection:** Copies custom Keycloak providers (JAR files) into the Keycloak installation directory.
-   **Keycloak Startup:** Starts Keycloak with the `oid4vc-vci` and `oid4vc-vpauth` features enabled, along with database configuration options.

## 1.oid4vci_test_deployment.sh

This script automates the deployment and configuration of the OID4VCI features within Keycloak, including realm creation, key management, client scope setup, and identity provider configuration.

**Key functionalities:**
-   **Keycloak Status Check:** Ensures that the Keycloak server is running.
-   **Admin Authentication:** Obtains an admin token using `kcadm.sh` for subsequent configuration tasks.
-   **Realm Creation:** Creates a new Keycloak realm as defined by `$KEYCLOAK_REALM`.
-   **Key Management:** Disables default generated keys (RSA-OAEP, RS256) and registers custom ECDSA, RSA signing, and RSA encryption key providers using JSON configuration files.
-   **Realm Attributes Update:** Updates the realm with custom attributes from `realm-attributes.json`.
-   **Client Scope Creation:** Creates OID4VCI credential client scopes based on `client-scope-config.json`, dynamically injecting the `ISSUER_DID`.
-   **SAML Identity Provider Setup:** Configures a SAML Identity Provider and its mappers using `saml-idp-config.json`, dynamically setting the `entityId`.
-   **Client Creation:** Creates the `openid4vc-rest-api` client and `oid4vc-demo-public` client, configuring their secrets, redirect URIs, and web origins.
-   **SD-JWT VCT Update:** Ensures the `sd-jwt` authenticator VCT is configured.
-   **Deployment Verification:** Checks if the Keycloak server is running and if the `SteuerberaterCredential`, `IdentityCredential`, and `KMACredential` configurations are exposed via client scopes.

## 3.request_credentials_with_auth_code_flow.sh

This script demonstrates how to request Verifiable Credentials using the Authorization Code Flow with PKCE (Proof Key for Code Exchange).

**Key functionalities:**
-   **Environment Loading:** Sources common environment variables.
-   **PKCE Generation:** Generates `code_verifier` and `code_challenge` for PKCE.
-   **Keycloak Health Check:** Waits for Keycloak to be available.
-   **Admin Authentication:** Configures Keycloak admin credentials if not already present.
-   **User Verification:** Checks if the user 'francis' exists.
-   **Key Proof Generation:** Generates a user key proof if it doesn't exist.
-   **Credential Request Function (`request_credential`):** This function encapsulates the logic for requesting a specific credential.
    -   Constructs an authorization URL with necessary parameters (scopes, issuer state, PKCE challenge, authorization details).
    -   Requires manual intervention to open the URL in a browser, log in as 'francis', and paste the authorization code back into the terminal.
    -   Exchanges the authorization code for an access token.
    -   Retrieves a `c_nonce` from the Keycloak nonce endpoint.
    -   Generates a key proof using `generate_key_proof.sh`.
    -   Prepares a credential request body with the credential identifier and the generated proof.
    -   Sends a POST request to the Keycloak credential endpoint to obtain the verifiable credential.
-   **Credential Tests:** Calls the `request_credential` function for `IdentityCredential`, `SteuerberaterCredential`, and `KMACredential`.

## 3.retrieve_IdentityCredential.sh

This script retrieves an `IdentityCredential` using a pre-authorized code flow.

**Key functionalities:**
-   **Environment Loading:** Sources common environment variables.
-   **Bearer Token Retrieval:** Obtains a bearer token for the user 'francis' using the password grant type.
-   **Credential Offer Link Retrieval:** Fetches the credential offer URI for `IdentityCredential`.
-   **Credential Offer Retrieval:** Retrieves the full credential offer using the link.
-   **Pre-Authorized Code Parsing:** Extracts the `pre-authorized_code` from the credential offer.
-   **C_Nonce Retrieval:** Obtains a `c_nonce` from the Keycloak nonce endpoint.
-   **Credential Bearer Token Acquisition:** Exchanges the `pre-authorized_code` for a credential bearer token.
-   **Key Proof Generation:** Generates a user key proof.
-   **Credential Request:** Prepares a request payload and obtains the `IdentityCredential` from the Keycloak credential endpoint.

## 3.retrieve_KMACredential.sh

This script retrieves a `KMACredential` using a pre-authorized code flow.

**Key functionalities:**
-   **Environment Loading:** Sources common environment variables.
-   **Bearer Token Retrieval:** Obtains a bearer token for the user 'francis' using the password grant type.
-   **Credential Offer Link Retrieval:** Fetches the credential offer URI for `KMACredential`.
-   **Credential Offer Retrieval:** Retrieves the full credential offer using the link.
-   **Pre-Authorized Code Parsing:** Extracts the `pre-authorized_code` from the credential offer.
-   **C_Nonce Retrieval:** Obtains a `c_nonce` from the Keycloak nonce endpoint.
-   **Credential Bearer Token Acquisition:** Exchanges the `pre-authorized_code` for a credential bearer token.
-   **Key Proof Generation:** Generates a user key proof.
-   **Credential Request:** Prepares a request payload and obtains the `KMACredential` from the Keycloak credential endpoint.