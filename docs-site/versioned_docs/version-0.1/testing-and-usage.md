# Testing and Usage

This section outlines how to test and use the SSI features provided by the Keycloak SSI Deployment. The project includes several scripts to demonstrate credential issuance and retrieval.

## Automated Credential Flows

The `3.request_credentials_with_auth_code_flow.sh` script demonstrates how to request credentials using the OAuth 2.0 Authorization Code Flow, a common pattern for secure authorization.

Following a successful request, you can retrieve specific credentials using scripts like:

*   **`3.retrieve_IdentityCredential.sh`**: Retrieves an "Identity Credential."
*   **`3.retrieve_KMACredential.sh`**: Retrieves a "KMA Credential."
*   **`3.retrieve_SteuerberaterCredential.sh`**: Retrieves a "Steuerberater Credential."

These scripts interact with the Keycloak instance and the OID4VC API to obtain verifiable credentials.

## Key Proof Generation

The `generate_key_proof.sh` script is used to generate a key proof, which is a cryptographic assertion demonstrating control over a private key associated with a decentralized identifier (DID). This is a fundamental aspect of SSI for proving ownership and authenticity.

The `user_key_proof_header.json` and `user_key_proof_payload.json` files likely contain components used in the key proof generation process, defining the structure and content of the proof.

## Updating SD-JWT VCT

The `update_sdjwt_vct.sh` script is related to updating the "Verifiable Credential Type" (VCT) in SD-JWT (Self-Describing JSON Web Tokens). SD-JWT is a format for verifiable credentials that allows for selective disclosure of claims, enhancing privacy. This script likely helps in managing or updating the type of credential being issued or verified within an SD-JWT context.