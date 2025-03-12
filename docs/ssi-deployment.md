## Introduction

This guide provides step-by-step instructions for configuring **Keycloak** as a **Verifiable Credential Issuer**. It covers the setup process for issuing **Verifiable Credentials (VCs)** using the OpenID for **Verifiable Credential Issuance (OID4VCI)** protocol. By the end of this guide, you will have a fully configured Keycloak instance capable of securely issuing and managing Verifiable Credentials.

## Prerequisite

* Ensure Keycloak is running with the **OID4VC_VCI** feature enabled.

<!-- To create a new realm , you can follo this link link:../topics/realms/proc-creating-a-realm.adoc[Creating a realm] -->

To configure keycloak as a VC Issuer, you can proceed as follows:

### Create a new realm

Using a dedicated realm instead of the default **master** realm improves security, isolates configurations, and simplifies management.

Procedure:

1. Log in to the **Keycloak Admin Console**.
2. In the left menu, click the dropdown showing the current realm (**master**).
3. Click **Create Realm** (top-left corner).
4. Enter a **Name** for the realm.
5. Click **Create** to save.

### Key Management Configuration

**Purpose:**  
Configuring key management is essential for securing the signing and encryption of **Verifiable Credentials (VCs)**. This involves disabling default keys and setting up custom key providers such as **ECDSA** and **RSA** to ensure cryptographic security.

**Disable Default Generated Keys:**  
By default, Keycloak generates signing and encryption keys (e.g., **RSA-OAEP, RS256**). Disabling these ensures only custom-configured keys are used.

Procedure:

1. In the left menu, go to **Realm Settings** → **Keys**.
2. Click on the **Add Providers** tab.
3. Identify the default keys (**rsa-enc-generated** and **rsa-generated**).
4. Click on each key, then select **Disable**.
5. Click **Save** to apply the changes.

**Configure Custom Key Providers:**
   - **ECDSA Key Provider:** 
     The script configures an ECDSA key provider by reading the `issuer_key_ecdsa.json` file. It uses the `jq` tool to inject specific keystore details, such as the keystore file path, password, type, key alias, and key password. This configuration is then registered with Keycloak to enable ECDSA signing.
   
   - **RSA Signing Key Provider:**  
     Similarly, the script configures an RSA signing key provider using the `issuer_key_rsa.json` file. The `jq` tool is again used to populate the necessary keystore information, which is then registered with Keycloak for RSA signing.
   
   - **RSA Encryption Key Provider:**  
     The script also sets up an RSA encryption key provider using the `encryption_key_rsa.json` file. This configuration is essential for encrypting credentials, ensuring that sensitive information is protected during transmission.

3. **Register Custom Keys with Keycloak:**
   - After configuring the key providers, the script registers them with Keycloak using the `kcadm.sh` tool. This step ensures that the custom keys are available for use in the credential issuance process.

By following these steps, the script ensures that Keycloak is configured with secure, custom key providers for signing and encrypting Verifiable Credentials. This enhances the overall security and integrity of the credential issuance process.

### 2-Create a Key Management
* Disables default generated keys:
** RSA-OAEP
** RS256
* Configures custom key providers:
** ECDSA signing key
** RSA signing key
** RSA encryption key

### 3-Create a Component Registration
* Creates signing service components for:
** SteuerberaterCredential
** IdentityCredential

### 4-Create a Client Configuration
* Creates and configures two clients:
** OID4VCI client
** OPENID4VC-REST-API client with custom redirect URIs and web origins

### 5-Verification
* Validates the deployment by checking the credential issuer endpoint
* Verifies the presence of supported credential configurations

## II-  configures a Keycloak instance by setting up a user account and configuring the OpenID4VC REST API client. It's part of a larger authentication and identity management setup.


=== 1. Administrative Setup
* Sources common environment variables
* Configures trust store settings
* Authenticates with Keycloak using admin credentials

=== 2. Configure the OpenID4VC REST API Client
* Retrieves the client configuration
* Stores the client ID in an environment variable
* Enables direct access grants for the client

=== 3. Create a user account
* Creates a new user named "Francis" with the following details:
** Username: francis
** First Name: Francis
** Last Name: Pouatcha
** Email: fpo@mail.de
* Sets the password for the user Francis

=== 4. Generate a user key
* Checks for existing user key proof header
* Generates new user keypair if none exists (via `generate_user_key.sh`)