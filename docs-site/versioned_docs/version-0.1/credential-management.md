# Credential Management

This section covers the process of managing credentials within the Keycloak SSI Deployment, including key generation and the issuance of verifiable credentials.

## Key Generation

Secure key management is crucial for SSI. This project provides scripts to generate various keys required for the Keycloak SSI setup:

*   **`generate_key_proof.sh`**: Generates a key proof, likely used for demonstrating ownership of a decentralized identifier (DID).
*   **`generate_keystore.sh`**: Generates a Keycloak keystore, which is essential for TLS/SSL and other cryptographic operations within Keycloak.
*   **`generate_user_key.sh`**: Generates keys for users, which can be used for signing and encryption in SSI contexts.
*   **`generate-kc-certs.sh`**: Generates certificates for Keycloak, important for secure communication.

These scripts typically output JSON Web Key (JWK) formatted keys or other cryptographic artifacts that are then used by Keycloak or other SSI components. For example, `issuer_key_ecdsa.json` and `issuer_key_rsa.json` are likely used by the Keycloak instance as issuer keys for signing verifiable credentials.

## Credential Issuance

The Keycloak SSI Deployment is configured to facilitate the issuance of verifiable credentials. While the exact flow depends on the specific SSI implementation, Keycloak acts as the Identity Provider (IdP) that authenticates users and authorizes the issuance of credentials.

The `credential_request_body.json` file likely contains a template or example of a credential request, outlining the type of credential being requested and any associated claims.

The scripts `3.request_credentials_with_auth_code_flow.sh`, `3.retrieve_IdentityCredential.sh`, `3.retrieve_KMACredential.sh`, and `3.retrieve_SteuerberaterCredential.sh` automated processes for requesting and retrieving specific types of credentials, demonstrating different credential issuance flows (e.g., using the OAuth 2.0 Authorization Code Flow).