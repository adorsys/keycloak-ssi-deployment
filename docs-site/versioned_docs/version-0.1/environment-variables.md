---
sidebar_position: 3
---

# Environment Variables

This document outlines the key environment variables used in the `keycloak-ssi-deployment` project. These variables configure various aspects of the Keycloak setup, database, and client interactions.

## Project Directories

*   **`WORK_DIR`**: The root directory of the project. Automatically set to the current working directory.
*   **`TARGET_DIR`**: The directory for build artifacts and generated files. Defaults to `$WORK_DIR/target`.
*   **`TOOLS_DIR`**: The directory for tools like the Keycloak installation. Defaults to `$TARGET_DIR/tools`.

## Keycloak Setup

*   **`KC_TARGET_BRANCH`**: The branch of the custom Keycloak repository to use (e.g., `datev/develop`).
*   **`KC_VERSION`**: The Keycloak version (e.g., `999.0.0-SNAPSHOT` for custom builds, or an official release version).
*   **`KC_OID4VCI`**: The directory name for the cloned Keycloak repository (e.g., `keycloak_datev/develop`).
*   **`KEYCLOAK_TARBALL`**: The path to the Keycloak tarball. Defaults to `$TARGET_DIR/keycloak-$KC_VERSION.tar.gz`.
*   **`KC_INSTALL_DIR`**: The Keycloak installation directory after unpacking. Defaults to `$TOOLS_DIR/keycloak-$KC_VERSION`.
*   **`KC_REPO_URL`**: The URL of the Keycloak repository to clone (e.g., `https://github.com/adorsys/keycloak-oid4vc.git`).

## Keycloak Credentials and Realm

*   **`KC_BOOTSTRAP_ADMIN_USERNAME`**: The username for the bootstrap Keycloak administrator (default: `admin`).
*   **`KC_BOOTSTRAP_ADMIN_PASSWORD`**: The password for the bootstrap Keycloak administrator (default: `admin`).
*   **`KEYCLOAK_REALM`**: The name of the Keycloak realm to be created or used (default: `oid4vc-vci`).

## Keystore Configuration

*   **`KEYCLOAK_KEYSTORE_FILE`**: The path to the Keycloak keystore file. Defaults to `$TARGET_DIR/kc_keystore.pkcs12`.
*   **`KEYCLOAK_KEYSTORE_TYPE`**: The type of the keystore (default: `PKCS12`).
*   **`KEYCLOAK_KEYSTORE_PASSWORD`**: The password for the keystore (default: `store_key_password`).
*   **`KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS`**: Alias for the ECDSA key in the keystore (default: `ecdsa_key`).
*   **`KEYCLOAK_KEYSTORE_RSA_SIG_KEY_ALIAS`**: Alias for the RSA signing key (default: `rsa_sig_key`).
*   **`KEYCLOAK_KEYSTORE_RSA_ENC_KEY_ALIAS`**: Alias for the RSA encryption key (default: `rsa_enc_key`).
*   **`KEYCLOAK_KEYSTORE_HMAC_SIG_KEY_ALIAS`**: Alias for the HMAC signing key (default: `hmac_sig_key`).
*   **`KEYCLOAK_KEYSTORE_AES_ENC_KEY_ALIAS`**: Alias for the AES encryption key (default: `aes_enc_key`).

## User and Client Credentials

*   **`USER_FRANCIS_NAME`**: Username for the example user 'Francis' (default: `francis`).
*   **`USER_FRANCIS_PASSWORD`**: Password for the example user 'Francis' (default: `francis`).
*   **`CLIENT_SECRET`**: Client secret for the `openid4vc-rest-api` client.

## Keycloak Network Configuration

*   **`KEYCLOAK_HTTPS_PORT`**: The HTTPS port for Keycloak (default: `8443`).
*   **`KEYCLOAK_ADMIN_ADDR`**: The administrative address of Keycloak (e.g., `https://localhost:8443`).
*   **`ISSUER_DID`**: The Decentralized Identifier (DID) for the issuer, derived from `KEYCLOAK_ADMIN_ADDR` and `KEYCLOAK_REALM`.
*   **`ISSUER_BACKEND_URL`**: The backend URL for the issuer (e.g., `https://issuer.eudi-adorsys.com/services`).
*   **`ISSUER_FRONTEND_URL`**: The frontend URL for the issuer (e.g., `https://issuer.eudi-adorsys.com`).
*   **`TEST_CLIENT_URL`**: The URL for the test client (e.g., `https://oid4vc-client.eudi-adorsys.com`).

## Francis Test Keystore

*   **`FRANCIS_KEYSTORE_FILE`**: Path to Francis's keystore file. Defaults to `$TARGET_DIR/francis_kc_keystore.pkcs12`.
*   **`FRANCIS_KEYSTORE_PASSWORD`**: Password for Francis's keystore (default: `francis_store_key_password`).
*   **`FRANCIS_KEYSTORE_TYPE`**: Type of Francis's keystore (default: `PKCS12`).
*   **`FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS`**: Alias for Francis's ECDSA key (default: `ecdsa_key`).

## Keycloak SSL Files

*   **`KC_SERVER_KEY`**: Path to the Keycloak server private key. Defaults to `$TARGET_DIR/keycloak-server.key.pem`.
*   **`KC_SERVER_CERT`**: Path to the Keycloak server certificate. Defaults to `$TARGET_DIR/keycloak-server.crt.pem`.
*   **`KC_TRUST_STORE`**: Path to the Keycloak trust store. Defaults to `$TARGET_DIR/cacerts`.
*   **`KC_TRUST_STORE_PASS`**: Password for the Keycloak trust store (default: `francis`).

## Database Configuration

*   **`KC_DB_EXPOSED_PORT`**: The exposed port for the PostgreSQL database container (default: `5433`).
*   **`KC_DB_NAME`**: The name of the Keycloak database (default: `keycloak`).
*   **`KC_DB_USERNAME`**: The username for the database (default: `postgres`).
*   **`KC_DB_PASSWORD`**: The password for the database (default: `postgres`).
*   **`KC_DB_OPTS`**: Optional manual database options, which take precedence over the above `KC_DB_*` variables if set.

## Keycloak Start Command

*   **`KC_START`**: The command used to start Keycloak. Configured for HTTPS with hostname strictness disabled, and log level set to debug.

## Keycloak Config CLI

*   **`REPO_URL`**: The URL of the `keycloak-config-cli` repository.
*   **`KC_CLI_JAR_FILE`**: The name of the `keycloak-config-cli` JAR file.
*   **`TAG`**: The specific tag/version of `keycloak-config-cli` to use (e.g., `v6.4.0`).
*   **`KEYCLOAK_URL`**: The URL of the Keycloak instance for the CLI to connect to.
*   **`KC_REALM_FILE`**: Path to the Keycloak realm configuration file (e.g., `$WORK_DIR/config/keycloak-config-dev.json`).
*   **`KC_CLI_PROJECT_DIR`**: The directory where the `keycloak-config-cli` project is cloned.
*   **`KC_KEYSTORE_PATH`**: The path to the Keycloak keystore file used by the CLI.