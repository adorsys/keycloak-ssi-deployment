# Keycloak as a Verifiable Credential Issuer with OID4VCI

This guide walks you through configuring Keycloak to issue Verifiable Credentials (VCs) using the OpenID for Verifiable Credential Issuance (OID4VCI) protocol.

# TLDR

Checkout this project.

## Checkout, Build, and Deploy Keycloak

### Prerequisites

Before proceeding, ensure you have the following tools installed on your system:

* **OpenSSL:** A command-line tool for working with SSL/TLS certificates, keys, and other cryptographic functions.
* **Keytool:** A Java key and certificate management utility included with the Java Development Kit (JDK).
* **jq (Optional):** `jq` is a handy command-line JSON processor that can simplify some of the configuration tasks in this guide.
* **.env File:** Review the `.env` file to ensure all the necessary environment variables are correctly set up.

**Verification:** You can verify that the tools are working by running:

```bash
openssl version
keytool -version
jq --version
```

### Setting Up Keycloak
You can set up Keycloak in one of two ways, based on your requirements:

1. **Using the Keycloak Tarball:** Downloads an official release from [Keycloak GitHub Releases](https://github.com/keycloak/keycloak/releases).
2. **Cloning and Building a Specific Keycloak Branch:** Builds Keycloak from a specific branch.

### Configuring the Setup Method
The setup method is controlled by the ```KC_USE_UPSTREAM``` environment variable:

- `true`: Use the Keycloak tarball.
- `false`: Clone and build a specific branch.

### Option 1: Using the Keycloak Tarball
Set ```KC_USE_UPSTREAM=true``` in the `.env file` and run:
  ```bash
  ./0.start-kc-oid4vci.sh
  ```
This will:

- Download and unpack the tarball (e.g., keycloak-26.0.7.tar.gz).
- Start Keycloak with OID4VCI feature on https://localhost:8443.

### Option 2: Cloning a Specific Branch
Set ```KC_USE_UPSTREAM=false``` in the `.env file` and run:
  ```bash
  ./0.start-kc-oid4vci.sh
  ```
This will:

- Clone and Build Keycloak from the specified branch.
- Start Keycloak with OID4VCI feature on https://localhost:8443.

## Keycloak Configuration for Verifiable Credential Issuance

To set up Keycloak for Verifiable Credential Issuance, we use a script that utilizes the **Keycloak Config CLI** tool. This script imports the necessary configurations into a dedicated realm.

### Step-by-Step Configuration

1. **Check the `.env` File**

   Before running the configuration script, ensure your `.env` file is set up correctly. This file contains important environment variables that connect the script to your Keycloak server.

   **Key variables to review:**
   - `KEYCLOAK_URL`: URL of your Keycloak server.
   - `KC_BOOTSTRAP_ADMIN_USERNAME`: Admin username for Keycloak.
   - `KC_BOOTSTRAP_ADMIN_PASSWORD`: Admin password for Keycloak.

2. **Run the Configuration Script**

   After verifying your `.env` file, run the following script to configure your Keycloak environment:

   ```bash
   # Import Keycloak configuration
   config/import_kc_config.sh
   ```

We can also configure Keycloak manually using the kcadm.sh tool. This shall be executed on the same machine, as it uses `kcadm.sh` on localhost to access the admin interface and shares generated keystore files with Keycloak.

### Prerequisites

Refer to the TLDR section for initial setup requirements.

### Script
In the project directory execute following scripts (tested on debian & ubuntu linux only):

```bash
# Configure oid4vci protocol
./1.oid4vci_test_deployment.sh
```

```bash
# Create a user account
./2.configure_user_4_account_client.sh
```

## Requesting Credentials
Uses only curl to access keycloak interfaces. The `-k` of curl disables ssl certificate validation.

### Request a credential without key binding
```bash
./3.retrieve_test_credential.sh
```

### Request a credential with key binding
```bash
./3.retrieve_IdentityCredential.sh
```

# Detailed Description

## Building and Deploying Keycloak

### Prerequisites

Refer to the TLDR section for initial setup requirements.

### The .env File
All environment variables defined here are to be found in a .env file, sourced ahead of executing any command.

### Using Keycloak with OID4VCI Support

The project uses the officially released version of Keycloak with OID4VCI support, and it also provides the option to clone and build a specific branch (e.g., for testing new features before integration).

### Cloning and Building Keycloak
The ```setup-kc-oid4vci.sh``` script simplifies the setup process. It either downloads a prebuilt tarball or builds Keycloak from source, depending on the ```KC_USE_UPSTREAM``` value.

  ```bash
  ./setup-kc-oid4vci.sh
  ```

This script:

- Downloads or builds Keycloak.
- Prepares Keycloak for OID4VCI usage.

```bash
echo "unpacking keycloak ..."
tar xzf "$TAR_FILE" -C "$TOOLS_DIR" || { echo "Could not unpack Keycloak tarball"; exit 1; }
echo "Keycloak unpacked to $KC_INSTALL_DIR."
```

```$TAR_FILE```: The path to the Keycloak tarball, either the upstream tarball (if using the official Keycloak release) or the custom build (if building from source).


### Generating SSL Keys for Keycloak

In this documentation, we run Keycloak with SSL enabled. This ensures consistent behavior with production setups and helps avoid potential issues when accessing the administration interface or integrating with other applications.

The following script, `generate-kc-certs.sh`, automates the process of creating a self-signed certificate for Keycloak. It then imports the certificate's public key into a truststore, which can be used by the Keycloak Admin CLI to establish a trusted connection.

The cert config file can be found at: ```cert-config.txt```
```bash
#!/bin/bash
# Source environment variables
. load_env.sh

openssl req -newkey rsa:2048 -nodes \
  -keyout "${KC_SERVER_KEY}" -x509 -days 3650 -out "${KC_SERVER_CERT}" -config "${WORK_DIR}/cert-config.txt"

keytool -importcert -trustcacerts -noprompt -alias localhost -file "${KC_SERVER_CERT}" -keystore "${KC_TRUST_STORE}" -storepass "${KC_TRUST_STORE_PASS}"
```

### Keycloak Startup with SSL

After setting up Keycloak and generating SSL keys, you can start Keycloak with OID4VCI features enabled. Use the ```0.start-kc-oid4vci.sh``` script:

This script:
- Shuts down any running Keycloak instance.
- Prepares Keycloak by running the setup script ```(setup-kc-oid4vci.sh)```.
- Starts the database container if not already running (Used for local development).
- Launches Keycloak with SSL, database connection, and OID4VCI support.

```bash
# Starts keycloak with OID4VCI feature

# Use org.keycloak.quarkus._private.IDELauncher if you want to debug through keycloak sources
export KC_BOOTSTRAP_ADMIN_USERNAME=$KC_BOOTSTRAP_ADMIN_USERNAME && export KC_BOOTSTRAP_ADMIN_PASSWORD=$KC_BOOTSTRAP_ADMIN_PASSWORD && cd $KC_INSTALL_DIR && bin/kc.sh $KC_START $KC_DB_OPTS --features=oid4vc-vci
```

For external deployments, **ensure you update the Keycloak admin password** to a more secure value.

Recall the start and database commands in `.env` file are:
```bash
KC_START="start --hostname-strict=false --https-port=$KEYCLOAK_HTTPS_PORT --https-certificate-file=$KC_SERVER_CERT --https-certificate-key-file=$KC_SERVER_KEY"
KC_DB_OPTS="--db postgres --db-url jdbc:postgresql://localhost:$KC_DB_EXPOSED_PORT/$KC_DB_NAME --db-username $KC_DB_USERNAME --db-password $KC_DB_PASSWORD"
```

## Configuring Keycloak to Service Verifiable Credentials

### Prerequisites

Refer to the TLDR section for initial setup requirements.

### All-in-One Deployment
All the steps outlined below can be executed by running the script ```1.oid4vci_test_deployment.sh```.

### Keycloak Admin CLI
Although Keycloak provides various integrated ways to manage configurations, we use the ```kcadm.sh``` CLI tool. This approach allows readers to work directly in a shell for quick results. For more complex deployments, consider using [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli).

### Accessing the Keycloak admin interface with SSL
The following lines will allow you to configure a truststore for used by ```kcadm.sh``` and obtain and administrator access token to perform administrative tasks.

```bash
# Set a trust store for kcadm.sh
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass $KC_TRUST_STORE_PASS $KC_TRUST_STORE
echo "Obtaining admin token..."
# Get admin token using environment variables for credentials
$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server $KEYCLOAK_ADMIN_ADDR --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD
```

### Setting the Issuer Identifier (DID)

In the decentralized identity ecosystem, a Decentralized Identifier (DID) serves as a unique identifier that resolves to a DID Document. This document contains information such as public keys and service endpoints for the associated entity. As a VC issuer, Keycloak requires a DID to identify itself. Other parties may dereference the DID Document (or its associated endpoint) to retrieve the cryptographic material needed to validate credentials issued by Keycloak.

The following batch command sets the `issuerDid` attribute for your realm using the value configured in your `.env` file:

```bash
# Add realm attribute issuerDid
echo "Updating realm attributes for issuerDid..."
$KC_INSTALL_DIR/bin/kcadm.sh update realms/$KEYCLOAK_REALM -s attributes.issuerDid=$ISSUER_DID || { echo 'Could not set issuer did' ; exit 1; }
```

### Configuring a Keycloak ECDSA Signing Key for Verifiable Credentials
Just like a regular bearer token, Keycloak issues VCs. These can be in various formats, such as SD-JWT (JSON documents). Keycloak can sign VCs using its native RSA key pair or, as required by some pilot programs, an Elliptic Curve (EC) key pair. In the latter case, we'll generate the EC key and add it to Keycloak's configuration.

**1. Generating an ECDSA Key:**

We'll use the `keytool` command (part of the Java Development Kit) to create an ECDSA key pair:
```bash
keytool \
  -genkeypair \
  -keyalg EC \
  -keysize 256 \
  -keystore "${KEYCLOAK_KEYSTORE_FILE}" \
  -storepass "${KEYCLOAK_KEYSTORE_PASSWORD}" \
  -alias "${KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS}" \
  -keypass "${KEYCLOAK_KEYSTORE_PASSWORD}" \
  -storetype "${KEYCLOAK_KEYSTORE_TYPE}" \
  -dname "CN=ECDSA Signing Key, OU=Keycloak, O=YourOrganization"
```

**2. Preparing the Keycloak Configuration:**

Next, we'll create a JSON file that describes the key to Keycloak. This file will be used by the `kcadm.sh` tool to add the key to the Keycloak configuration.

```json
{
  "id": "ecdsa-issuer-key",
  "name": "ecdsa-issuer-key",
  "providerId": "java-keystore",
  "providerType": "org.keycloak.keys.KeyProvider",
  "config": {
    "keystore": ["${KEYCLOAK_KEYSTORE_FILE}"],
    "keystoreType": ["${KEYCLOAK_KEYSTORE_TYPE}"],
    "keystorePassword": ["${KEYCLOAK_KEYSTORE_PASSWORD}"],
    "keyAlias": ["${KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS}"],
    "keyPassword": ["${KEYCLOAK_KEYSTORE_PASSWORD}"],
    "active": ["true"],
    "priority": ["0"],
    "enabled": ["true"],
    "algorithm": ["ES256"]
  }
}
```

**Key points:**
* `providerId`: "java-keystore" refers to the Keycloak Java KeyStore key provider.
* `algorithm`: "ES256" specifies the ECDSA algorithm with SHA-256.

**3. Adding the Key to Keycloak:**

In order to fill up this template in a shell environment, we need a tool like ```jq```, that can manipulate json files on the
command line (as mentioned in the prerequisites).

```bash
# Add concrete info and passwords to key provider
echo "Configuring ecdsa key provider..."
cat $WORK_DIR/issuer_key_ecdsa.json | \
  jq --arg keystore "$KEYCLOAK_KEYSTORE_FILE" \
  --arg keystorePassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  --arg keystoreType "$KEYCLOAK_KEYSTORE_TYPE" \
  --arg keyAlias "$KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS" \
  --arg keyPassword "$KEYCLOAK_KEYSTORE_PASSWORD" \
  '.config.keystore = [$keystore] | 
   .config.keystorePassword = [$keystorePassword] |
   .config.keystoreType = [$keystoreType] | 
   .config.keyAlias = [$keyAlias] | 
   .config.keyPassword = [$keyPassword]' \
  > $TARGET_DIR/issuer_key_ecdsa-tmp.json 
```

**4. Adding the Key to the Keycloak Realm:**

The following Bash command adds an EC key to the Keycloak realm specified in the ```.env``` file and configures it to produce JWS ES256 signatures (ECDSA on curve P-256):

```bash
# Register the EC-key with Keycloak
echo "Registering issuer key ecdsa..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - < $TARGET_DIR/issuer_key_ecdsa-tmp.json || { echo 'ECDSA Issuer Key registration failed' ; exit 1; }
```

### Defining VCs in Keycloak

Keycloak's strength as an identity provider naturally extends to its role as a VC issuer. VCs, like tokens, are digitally signed pieces of information, but they go beyond authentication to grant specific rights or attributes. By leveraging Keycloak's established infrastructure, organizations can benefit from its extensive experience in managing and securing identity-related data, including the crucial signing keys used for VCs.

#### VCs as Tokens

In Keycloak, the structure of a VC closely resembles that of a token. Both are essentially claims about an entity (a user, organization, etc.), packaged in a structured format and digitally signed for authenticity.

#### Protocol Mappers: Shaping VC Content

Just as Keycloak's protocol mappers determine the information included in a token, they play a vital role in shaping the content of VCs. These mappers are responsible for:

1. **Retrieving:** Fetching data from Keycloak's user database or external sources.
2. **Formatting:** Transforming the data into the appropriate format for the VC.
3. **Adding:** Including the formatted data as claims within the VC.

#### Clients and the OID4VCI Protocol

The definition of a VC's structure in Keycloak is closely tied to the *client* that requests it. In the context of VCs, the client interacts with Keycloak using the OID4VCI protocol, which defines the necessary endpoints for requesting and receiving VCs.

A Keycloak client configuration for OID4VCI looks like this:

```json
{
  "clientId": "oid4vci-client",
  "name": "OID4VC-VCI Client",
  "protocol": "oid4vc",
  "enabled": true,
  "publicClient": true,
  "attributes": {
    "vc.test-credential.expiry_in_s": 100,
    "vc.test-credential.format": "vc+sd-jwt",
    "vc.test-credential.scope": "test-credential",
    "// ...": "other VC configurations for additional credential types"
  },
  "protocolMappers": [
    "// ... (protocol mapper definitions)"
  ]
}
```

#### Creating the OID4VCI Client

To register this client with Keycloak, use the following command:

```bash
# Create client for oid4vci
echo "Creating OID4VCI client..."
$KC_INSTALL_DIR/bin/kcadm.sh create clients -o -f - < $WORK_DIR/client-oid4vc.json || { echo 'OID4VCIClient creation failed' ; exit 1; }
```

#### Protocol Mapper Example

Here's an example of a protocol mapper within the client configuration:

```json
{
  "id": "given_name-mapper-001",
  "name": "given_name-mapper",
  "protocol": "oid4vc",
  "protocolMapper": "oid4vc-user-attribute-mapper",
  "config": {
    "subjectProperty": "given_name",
    "userAttribute": "firstName",
    "supportedCredentialTypes": "identity_credential"
  }
}
```

This mapper extracts the user's `firstName` attribute and includes it as the `given_name` claim in VCs of the "identity_credential" type.

## Verifiable Credential Formats and Signing Services

Keycloak's OID4VCI implementation supports multiple formats for VCs, including:

* **LDP_VC:** Linked Data Proof Verifiable Credentials, as defined in the W3C Verifiable Credentials Data Model specification ([https://www.w3.org/TR/vc-data-model/](https://www.w3.org/TR/vc-data-model/)).
* **JWT_VC:** JSON Web Token Verifiable Credentials, based on the JWT VC Presentation Profile ([https://identity.foundation/jwt-vc-presentation-profile/](https://identity.foundation/jwt-vc-presentation-profile/)).
* **SD-JWT:**  Self-Issued OpenID Provider (SIOP) v2 JSON Web Token Verifiable Credentials, as defined in the IETF OAuth SD-JWT VC draft ([https://drafts.oauth.net/oauth-sd-jwt-vc/draft-ietf-oauth-sd-jwt-vc.html](https://drafts.oauth.net/oauth-sd-jwt-vc/draft-ietf-oauth-sd-jwt-vc.html)).

Each format has its own way of representing and signing the VC. Keycloak utilizes the `VerifiableCredentialsSigningService` interface to accommodate these different formats.

### Signing Service Configurations

To support a specific format, a corresponding signing service must be active.  Signing services can be configured to handle all credential types of a given format. However, you'll often need specific signing service configurations for certain credential types, allowing you to tailor the signing process to their unique requirements.

#### Example: Signing Service for `IdentityCredential`

Here's an example of a signing service configuration for a credential type called `IdentityCredential` using the SD-JWT format:

```json
{
  "id": "sd-jwt-signing/IdentityCredential",
  "name": "sd-jwt-signing-service for IdentityCredential",
  "providerId": "vc+sd-jwt",
  "providerType": "org.keycloak.protocol.oid4vc.issuance.signing.VerifiableCredentialsSigningService",
  "config": {
    "algorithmType": ["ES256"],
    "hashAlgorithm": ["sha-256"],
    "tokenType": ["vc+sd-jwt"],
    "vcConfigId": ["IdentityCredential"],
    "decoys": [2]  
  }
}
```
**Note:** decoys are optional number of decoy claims for privacy enhancement

**Key Configuration Points:**

* **`providerId`:** Indicates the VC format this service handles ("vc+sd-jwt" for SD-JWT).
* **`vcConfigId`:** Identifies the specific credential type this instance is responsible for ("IdentityCredential" in this case).
* **`algorithmType`:** Specifies the signing algorithm (e.g., "ES256" for ECDSA with SHA-256). If you don't provide a specific key ID, Keycloak will automatically select the active key that supports the specified algorithm.

**Registering a Signing Service:**

You can register this signing service with Keycloak using the following command:

```bash
echo "Creating signing service component for IdentityCredential..."
$KC_INSTALL_DIR/bin/kcadm.sh create components -r $KEYCLOAK_REALM -o -f - < "$WORK_DIR/signing_service-IdentityCredential.json" || { echo 'Could not create signing service component for IdentityCredential' ; exit 1; }
```

After registering a signing service, keycloak is ready to deliver a verifiable credential for the given credential type and format.

# Key Endpoints

## Credential Issuer Metadata Endpoint

This endpoint is **mandatory** and describes the issuer's capabilities, including supported credential types, formats, cryptographic binding methods, and display information. It also provides the URLs for other essential endpoints like the `credential_endpoint`, `batch_credential_endpoint`, and `deferred_credential_endpoint`. The current keycloak implementation supports only the credential endpoint.

* URL: `https://<your-keycloak-host>/realms/<your-realm>/.well-known/openid-credential-issuer`
* e.g: `https://localhost:8443/realms/master/.well-known/openid-credential-issuer`

### OpenID Configuration Endpoint

This endpoint is **mandatory** in OpenID Connect and provides general metadata about the issuer's OpenID Connect configuration, such as supported scopes, response types, and grant types. While not specific to OID4VCI, it's essential for the overall OpenID Connect flow that underpins VC issuance.

* URL: `https://<your-keycloak-host>/realms/<your-realm>/.well-known/openid-configuration`
* e.g.: `https://localhost:8443/realms/master/.well-known/openid-configuration`

### JWT Issuer Endpoint

This endpoint is **optional** and provides metadata specifically about the issuer's JWT-based VCs. It includes information about supported algorithms, key IDs, and other details relevant to JWT-based VCs.

* URL: `https://<your-keycloak-host>/realms/<your-realm>/.well-known/jwt-vc-issuer`
* e.g: `https://localhost:8443/realms/master/.well-known/jwt-vc-issuer`


## Creating User and User key Materials

### Registering a User

The script `2.configure_user_4_account_client.sh` allows the registration of a new Keycloak user. This user will be used for requesting VCs later in the process.

### Creating User Key Material

Certain credential types require cryptographic binding to the user's identity. This is achieved by associating the VC with a key pair controlled by the user. The script `2.configure_user_4_account_client.sh` also calls `generate_user_key.sh` to generate an ECDSA (Elliptic Curve Digital Signature Algorithm) key pair for this purpose. The user will use the private key to sign proofs during VC interactions, while the public key will be included in the VC.

## Requesting Verifiable Credentials

For these examples, we will be using the **pre-authorized_code** flow.

* The script `3.retrieve_SteuerberaterCredential.sh` will allow you to request and obtain a test_credential, without holder binding.
* The script `3.retrieve_IdentityCredential.sh` with create a key pair for the wallet, sign a key proof and use it to request an IdentityCredential with key binding.
