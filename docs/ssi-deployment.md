## Introduction

This guide provides step-by-step instructions for configuring **Keycloak** as a **Verifiable Credential Issuer**. It covers the setup process for issuing **Verifiable Credentials (VCs)** using the OpenID for **Verifiable Credential Issuance (OID4VCI)** protocol. By the end of this guide, you will have a fully configured Keycloak instance capable of securely issuing and managing Verifiable Credentials.

### What are Verifiable Credentials (VCs)?
**Verifiable Credentials (VCs)** are cryptographically signed, tamper-evident data structures representing claims about an entity (e.g., a person, organization, or device). They form the foundation of decentralized identity systems, enabling secure and privacy-preserving identity verification without relying on centralized authorities. VCs support advanced cryptographic mechanisms such as selective disclosure and zero-knowledge proofs.

### What is OID4VCI?
**OpenID for Verifiable Credential Issuance (OID4VCI)** is an extension of the **OpenID Connect (OIDC)** protocol, designed to standardize the issuance of Verifiable Credentials. It defines an interoperable framework for credential issuers to securely deliver VCs to holders, who can then present them to verifiers.

### Scope
The guide includes the following technical configurations:

* Creating a realm dedicated to VC issuance.
* Setting up a test user for credential testing.
* Configuring custom cryptographic keys for signing and encrypting VCs.
* Defining realm attributes for VC metadata.
* Establishing client scopes and mappers for user attribute inclusion in VCs.
* Registering a client to manage VC requests.
* Configuring a credential builder for VC formatting.
* Verifying the configuration via the issuer metadata endpoint.

## Prerequisite

Before proceeding, ensure the following requirements are met:

  **1. Keycloak Instance:**
  * A running Keycloak server with the OID4VCI feature enabled. Enable the feature by adding the following flag to the startup command:
    ```bash
      --features=oid4vc-vci
    ```
  * Verify successful activation by checking the server logs for the OID4VC_VCI initialization message.

  **2. Authentication:**
  * Obtain an access token to authenticate API requests.

🔗 **Reference:** For detailed instructions on setting up clients and requesting an access token, refer to the [official Keycloak documentation.](https://www.keycloak.org/docs/latest/authorization_services/index.html)

### Configuring Keycloak as a VC Issuer
Follow the steps below to configure Keycloak for issuing Verifiable Credentials.

### Create a new realm

Using a dedicated realm instead of the default **master** realm improves security, isolates configurations, and simplifies management.

Run the command below to create a realm:

  ```bash
    kcadm.sh create realms -s realm=$REALM_NAME -s enabled=true
  ```

Parameters:

  `-s realm=$REALM_NAME`: Specifies the realm name.
  
  `-s enabled=true`: Activates the realm upon creation.

### Create a User Account

After setting up the realm, create a user account to facilitate testing and authentication.

Run the command below to create the User:

  ```bash
    kcadm.sh create users -r $REALM_NAME -s username=$USERNAME -s firstName=$USER_FIRST_NAME -s lastName=$USER_LAST_NAME -s email=$USER_EMAIL -s enabled=true
  ```

Parameters:

  `-r $REALM_NAME`: Targets the oid4vc-vci realm.

  `-s username=$USERNAME`: Sets the username.

  `-s firstName=$USER_FIRST_NAME`: Assigns the first name.

  `-s lastName=$USER_LAST_NAME`: Assigns the last name.

  `-s email=$USER_EMAIL`: Sets the email address.

  `-s enabled=true`: Enables the user account.

Set the User's Password:

After creating the user, define a password using the following command:

  ```bash
    kcadm.sh set-password -r $REALM_NAME --username $USERNAME --new-password $USER_PASSWORD
  ```

Parameters

  `--username $USERNAME`: Identifies the target user.
  
  `--new-password $USER_PASSWORD`: Sets the user password (use a strong, unique password in production).

### Key Management Configuration

**Purpose:**  
Configuring key management is essential for securing the signing and encryption of **Verifiable Credentials (VCs)**. This involves disabling default keys and setting up custom key providers such as **ECDSA** and **RSA** to ensure cryptographic security.

**Disable Default Generated Keys:**  
By default, Keycloak generates signing and encryption keys (e.g., **RSA-OAEP, RS256**). Disabling these ensures only custom-configured keys are used.

Run the command below to retrieve and disable the active keys:

  ```bash
    # Disable the RSA-OAEP key
    kcadm.sh get keys -r $KEYCLOAK_REALM --fields 'active(RSA-OAEP)' | jq -r '.active."RSA-OAEP"'
    $KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RSA_OAEP_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId'
    echo "Disabling RSA-OAEP key... KID=$RSA_OAEP_KID PROV_ID=$RSA_OAEP_PROV_ID"
    kcadm.sh delete keys/$RSA_OAEP_PROV_ID -r $KEYCLOAK_REALM

    # Disable the RS256 key
    RS256_KID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM --fields 'active(RS256)' | jq -r '.active.RS256')
    RS256_PROV_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get keys -r $KEYCLOAK_REALM | jq --arg kid "$RS256_KID" '.keys[] | select(.kid == $kid)' | jq -r '.providerId')
    echo "Disabling RS256 key... KID=$RS256_KID PROV_ID=$RS256_PROV_ID"
    kcadm.sh delete keys/$RS256_PROV_ID -r $KEYCLOAK_REALM
  ```

**Configure Custom Key Providers:**

To securely sign and encrypt **Verifiable Credentials (VCs)**, configure custom key providers in Keycloak. This setup loads cryptographic keys from a Java (PKCS12) Keystore.

- **1. Adding an ECDSA Key Provider:** 

ECDSA keys provide an efficient and secure mechanism for signing credentials. To add an ES256 (ECDSA with SHA-256) key provider, run the following command:

  ```bash
    kcadm.sh create keys -r <REALM> -s providerId=java-keystore \
    -s "config.keystore=<KEYSTORE_PATH>" \
    -s "config.keystorePassword=<KEYSTORE_PASSWORD>" \
    -s "config.keystoreAlias=<KEY_ALIAS>" \
    -s "config.keyPassword=<KEY_PASSWORD>" \
    -s "config.keyType=EC" \
    -s "config.algorithm=ES256" \
    -s "config.priority=100" \
    -s "config.active=true" \
    -s "config.enabled=true"
  ```

- **Adding an RSA Signing Key Provider:**  

To use RS256 (RSA with SHA-256) for signing, add an RSA key provider with the following command:

  ```bash
    kcadm.sh create keys -r <REALM> -s providerId=java-keystore \
    -s "config.keystore=<KEYSTORE_PATH>" \
    -s "config.keystorePassword=<KEYSTORE_PASSWORD>" \
    -s "config.keystoreAlias=<KEY_ALIAS>" \
    -s "config.keyPassword=<KEY_PASSWORD>" \
    -s "config.keyType=RSA" \
    -s "config.algorithm=RS256" \
    -s "config.priority=90" \
    -s "config.active=true" \
    -s "config.enabled=true"
  ```
   
- **Adding an RSA Encryption Key Provider:**  

For RSA-OAEP (Optimal Asymmetric Encryption Padding) encryption, configure an RSA key provider with:

  ```bash
    kcadm.sh create keys -r <REALM> -s providerId=java-keystore \
    -s "config.keystore=<KEYSTORE_PATH>" \
    -s "config.keystorePassword=<KEYSTORE_PASSWORD>" \
    -s "config.keystoreAlias=<KEY_ALIAS>" \
    -s "config.keyPassword=<KEY_PASSWORD>" \
    -s "config.keyType=RSA" \
    -s "config.algorithm=RSA-OAEP" \
    -s "config.priority=80" \
    -s "config.active=true" \
    -s "config.enabled=true"
  ```

**Note:** Replace the placeholders (`<REALM>`, `<KEYSTORE_PATH>`, etc.) with appropriate values.

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
