## Introduction

This guide provides step-by-step instructions for configuring **Keycloak** as a **Verifiable Credential Issuer**. It covers the setup process for issuing **Verifiable Credentials (VCs)** using the OpenID for **Verifiable Credential Issuance (OID4VCI)** protocol. By the end of this guide, you will have a fully configured Keycloak instance capable of securely issuing and managing Verifiable Credentials.

## Prerequisite

* Ensure **Keycloak** is running with the **OID4VC_VCI** feature enabled.
* Have an **access token** to authenticate API requests.

🔗 **Refer to the official Keycloak documentation** for steps on:

* Setting up clients
* Requesting an access token

👉 Guide: [Keycloak Authentication & Token Requests](https://www.keycloak.org/docs/latest/authorization_services/index.html). This token will be required for various API requests throughout this guide.

To configure keycloak as a VC Issuer, you can proceed as follows:

### Create a new realm

Using a dedicated realm instead of the default **master** realm improves security, isolates configurations, and simplifies management.

Procedure:

  1. Log in to the **Keycloak Admin Console**.
  2. In the left menu, click the dropdown showing the current realm (**master**).
  3. Click **Create Realm** (top-left corner).
  4. Enter a **Name** for the realm.
  5. Click **Create** to save.

### Create a User Account

After setting up the realm, create a user account to facilitate testing and authentication.

Procedure:

  1. In the **Keycloak Admin Console**, navigate to **Users** → Click **Add User**.
  2. Enter the user details:
     * **Username:** Define a unique username.
     * **First Name:** Enter the user's first name.
     * **Last Name:** Enter the user's last name.
     * **Email:** Provide a valid email address.
  3. Click **Save** to create the user.
  4. Navigate to the **Credentials** tab → Click **Set Password**
  5. Enter and confirm the user's password.
  6. Click **Save** to apply the changes.

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

To securely sign and encrypt **Verifiable Credentials (VCs)**, configure custom key providers in Keycloak. This involves setting up **ECDSA** and **RSA** keys through the **Keycloak Admin Console**, loaded from a keystore.

   - **Adding an ECDSA Key Provider:** 
     1. Navigate to **Realm Settings** → **Keys**.
     2. Click **Add Provider**, then select **java-keystore** from the list.
     3. Fill in the required fields:
        * **Keystore:** Path to the keystore file.
        * **Keystore Type:** Format of the keystore (e.g., JKS or PKCS12).
        * **Keystore Password:** Password used to access the keystore.
        * **Key Alias:** Alias of the key inside the keystore.
        * **Key Password:** Password for the key inside the keystore.
        * **Algorithm:** Select ES256 for ECDSA signing.
        * **Priority:** Set the key’s precedence.
        * **Key use:** Choose signing.
     4. Ensure **Active** and **Enabled** are set to **true**.
     5. Click **Save** to register the key provider.
   
   - **Adding an RSA Signing Key Provider:**  
     1. Navigate to **Realm Settings** → **Keys**.
     2. Click **Add Provider**, then select **java-keystore** from the list.
     3. Fill in the required fields:
        * **Keystore:** Path to the keystore file.
        * **Keystore Type:** Format of the keystore (JKS or PKCS12).
        * **Keystore Password:** Password used to access the keystore.
        * **Key Alias:** Alias of the key inside the keystore.
        * **Key Password:** Password for the key inside the keystore.
        * **Algorithm:** Select RS256 for RSA signing.
        * **Priority:** Set the key’s precedence.
        * **Key Use:** Choose signing.
     4. Ensure **Active** and **Enabled** are set to true.
     5. Click **Save** to register the key provider.
   
   - **Adding an RSA Encryption Key Provider:**  
     1. Navigate to **Realm Settings** → **Keys**.
     2. Click **Add Provider**, then select **java-keystore** from the list.
     3. Fill in the required fields:
        * **Keystore:** Path to the keystore file.
        * **Keystore Type:** Format of the keystore (JKS or PKCS12).
        * **Keystore Password:** Password used to access the keystore.
        * **Key Alias:** Alias of the key inside the keystore.
        * **Key Password:** Password for the key inside the keystore.
        * **Algorithm:** Select RSA-OAEP for encryption.
        * **Priority:** Set the key’s precedence.
        * **Key Use:** Choose encryption.
     4. Ensure **Active** and **Enabled** are set to true.
     5. Click **Save** to register the key provider.

### Registering Attributes at the Realm Level

Before issuing **Verifiable Credentials (VCs)**, we must define the attributes that will be part of the issued credentials. Since the Keycloak Admin Console does not support direct attribute creation, we define these attributes in a **JSON file** and import them into Keycloak. This method ensures flexibility, consistency, and easy automation.

  **Defining Realm Attributes in a JSON File:**
     Create a JSON file (e.g., `realm-attributes.json`) containing the necessary attributes:

      ```json
          {
            "realm": "oid4vc-vci",
            "enabled": true,
            "preAuthorizedCodeLifespanS": 120,
            "issuerDid": "https://localhost:8443/realms/oid4vc-vci",
            "attributes": {
              "vc.IdentityCredential.expiry_in_s": 31536000,
              "vc.IdentityCredential.format": "vc+sd-jwt",
              "vc.IdentityCredential.scope": "identity_credential",
              "vc.IdentityCredential.vct": "https://credentials.example.com/identity_credential",

              "vc.SteuerberaterCredential.expiry_in_s": 31536000,
              "vc.SteuerberaterCredential.format": "vc+sd-jwt",
              "vc.SteuerberaterCredential.scope": "stbk_westfalen_lippe",
              "vc.SteuerberaterCredential.vct": "stbk_westfalen_lippe",
              "vc.SteuerberaterCredential.cryptographic_binding_methods_supported": "jwk",
            }
          }
      ```        

**Key Attributes and Their Purpose**

  * **preAuthorizedCodeLifespanS:** Defines the lifespan (in seconds) of a pre-authorized code before it expires. This enhances security by ensuring that issued credentials cannot be used indefinitely.

  * **issuerDid:** Specifies the Decentralized Identifier (DID) of the issuer, representing the entity responsible for issuing Verifiable Credentials. This is crucial for trust and verification within decentralized identity ecosystems.

        
  **Importing the Attributes into Keycloak REST API:** Use the following command to send a request to create the attributes

    ```bash
      curl -k -X POST "https://localhost:8443/admin/realms/master/attributes" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @realm-attributes.json
    ```

💡 Note: The -k (or --insecure) option in curl is used to bypass SSL certificate verification, which is useful when running Keycloak with self-signed certificates. However, in a production environment, use a trusted SSL certificate instead.

These attributes will be used in mappers to include them in the issued Credential.

### Creating Client Scopes with Mappers

Client Scopes allow us to control which attributes are included in the issued credentials by mapping user attributes to claims.

  **Defining Client Scopes and Mappers in JSON:**
    Create a JSON file (`client-scopes.json`) to define the required client scopes:

      ```json
        {
          "name": "vc-scope-mapping",
          "protocol": "openid-connect",
          "attributes": {
            "include.in.token.scope": "false",
            "display.on.consent.screen": "false"
          },
          "protocolMappers": [
            {
              "name": "academic_title-mapper-bsk",
              "protocol": "oid4vc",
              "protocolMapper": "oid4vc-static-claim-mapper",
              "config": {
                "subjectProperty": "academic_title",
                "staticValue": "N/A",
                "supportedCredentialTypes": "stbk_westfalen_lippe"
              }
            }
          ]
        }
      ```

  **Importing Client Scopes via REST API**

    ```bash
      curl -k -X POST "https://localhost:8443/admin/realms/oid4vc-vci/client-scopes" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @client-scopes.json
    ```

This configuration ensures that user attribute **academic_title** is included in the issued Credential.

### Creating the oid4vc-rest-api Client
This client is responsible for handling Verifiable Credential requests and must be assigned the necessary client scopes.

  **Defining the Client Configuration in JSON:** Create a JSON file (`oid4vc-rest-api-client.json`) for the client definition

      ```json
        {
          "clientId": "oid4vc-rest-api",
          "enabled": true,
          "protocol": "openid-connect",
          "publicClient": false,
          "serviceAccountsEnabled": true,
          "clientAuthenticatorType": "client-secret",
          "redirectUris": ["http://localhost:8080/*"],
          "clientAuthenticatorType": "client-secret",
          "directAccessGrantsEnabled": true,
          "defaultClientScopes": ["profile"],
          "optionalClientScopes": ["vc-scope-mapping"],
          "attributes": {
            "client.secret.creation.time": "1719785014",
            "client.introspection.response.allow.jwt.claim.enabled": "false",
            "login_theme": "keycloak",
            "post.logout.redirect.uris": "http://localhost:8080",
          }
        }
      ```
  **Importing the Client via REST API**

    ```bash
      curl -k -X POST "https://localhost:8443/admin/realms/oid4vc-vci/clients" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @oid4vc-rest-api-client.json
    ```

💡 Note: Make sure the client is assigned the scope we created above (**vc-scope-mapping**) so that it can request the credential.

### Create a Credential Builder Component

The Credential Builder is responsible for handling specific credential formats. To configure a credential builder in Keycloak, we will use the Keycloak Admin API:

  ```json
    curl -k -X POST "https://localhost:8443/admin/realms/oid4vc-vci/components" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "sd-jwt-credentialbuilder",
        "providerId": "vc+sd-jwt",
        "providerType": "org.keycloak.protocol.oid4vc.issuance.credentialbuilder.CredentialBuilder"
      }'
  ```

This request registers a **credential builder** named **sd-jwt-credentialbuilder**, which will handle the creation of **SD-JWT-based verifiable credentials** in Keycloak.

💡 Note: Ensure you have a valid access token (**$ACCESS_TOKEN**) before making this request.

### Verifying the Configuration

To ensure that the Verifiable Credential (VC) issuance setup has been correctly applied, validate the realm configuration by accessing the following endpoint:

🔗 Verify Configuration: **keycloak_url/realms/{realm}/.well-known/openid-credential-issuer**

A successful response should return a JSON object containing key details such as the claims, credential configurations supported, format, and other relevant attributes. This confirms that the realm and its associated attributes have been properly configured.

### Conclusion

With the realm configuration now complete, Keycloak is fully prepared to issue **Verifiable Credentials (VCs)** in alignment with the **OpenID for Verifiable Credentials (OID4VC)** standard. By structuring the configuration through JSON-defined attributes and leveraging the Keycloak Admin API, this approach ensures a scalable, maintainable, and secure implementation.
