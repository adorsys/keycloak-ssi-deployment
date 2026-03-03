# Keycloak SSI Deployment - Terraform Configuration

This directory contains Terraform configuration files for deploying and configuring Keycloak with OpenID4VCI (OpenID for Verifiable Credential Issuance) capabilities for Self-Sovereign Identity (SSI) applications.

## Overview

The Terraform configuration automates the setup of a Keycloak realm with:

- **Realm Configuration**: Creates a dedicated realm for OpenID4VCI operations
- **User Management**: Sets up test users with predefined credentials
- **Client Scopes**: Configures credential-specific client scopes for different credential types
- **Client Configuration**: Sets up the OpenID4VCI REST API client
- **Key Management**: Imports and configures cryptographic keys for signing and encryption
- **SAML Identity Provider**: Configures SAML-based identity provider with user attribute mappers

## Prerequisites

Before running this Terraform configuration, ensure you have:

1. **Terraform** installed (version 1.0+)
2. **Keycloak** running and accessible
3. **jq** command-line JSON processor installed
4. **curl** for HTTP requests
5. **bash** shell environment

## Architecture

The configuration is organized into modular components:

```
infrastructure/terraform/
├── main.tf                 # Main configuration file
├── provider.tf             # Keycloak provider configuration
├── variables.tf            # Input variables
├── modules/
│   ├── realm/              # Realm creation and configuration
│   ├── users/              # User management
│   ├── client_scopes/      # Client scope configuration
│   ├── clients/            # Client configuration
│   ├── keys/               # Cryptographic key management
│   └── saml_idp/           # SAML Identity Provider configuration
└── jsons/                  # JSON configuration files
    ├── keys/               # Key configuration files
    ├── scopes/             # Client scope definitions
    └── identity_providers/ # Identity provider configurations
```

## Configuration

### Variables

The main variables are defined in the root `variables.tf` and module-specific `variables.tf` files. The most important ones are:

| Variable                  | Description                                           | Default Value            |
| ------------------------- | ----------------------------------------------------- | ------------------------ |
| `keycloak_url`           | Keycloak base URL                                     | `https://localhost:8443` |
| `admin_password`         | Keycloak admin password                               | `admin`                  |
| `realm`                  | Keycloak realm name used for the OID4VCI issuer       | `oid4vc-vci`             |
| `status_list_server_url` | Base URL of the status list server                    | `https://statuslist.eudi-adorsys.com` |
| `status_list_enabled`    | Turns status list support on or off for the realm     | `false`                  |

Additional tuning options (for example optional client scopes, sd-jwt VCTs, initial passwords, and module-specific
settings like the login theme) can be seen in the various `variables.tf` files and adjusted as needed.

### Key and Status List Configuration

The keys module imports three types of cryptographic keys:

- **ECDSA Issuer Key**: For signing verifiable credentials
- **RSA Issuer Key**: Alternative signing key
- **RSA Encryption Key**: For encrypting sensitive data

If you set `status_list_enabled` to `true`, Keycloak adds status information to issued credentials using
`status_list_server_url`. This lets wallets and verifiers check whether a credential is still valid, revoked, or suspended.

### SAML Identity Provider Configuration

The saml_idp module imports a SAML-based identity provider with:

- **SAML IdP Configuration**: Complete SAML identity provider setup with signing certificates
- **User Attribute Mappers**: Automatic mapping of email, firstName, and lastName attributes
- **Security Settings**: Signature validation, binding configuration, and authentication policies

## Usage

### 1. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

This will show you what resources will be created/modified.

### 3. Apply the Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm the deployment.

### 4. Verify Deployment

After successful deployment, you can verify:

- **Realm**: Check if the `oid4vc-vci` realm exists
- **Users**: Verify test user `francis` is created
- **Client Scopes**: Confirm credential scopes are configured
- **Keys**: Validate cryptographic keys are imported
- **SAML IdP**: Verify SAML identity provider and mappers are configured

### 5. Destroy Resources (Optional)

To remove all created resources:

```bash
terraform destroy -auto-approve
```

## Key Features

### Automatic Key Disabling

The configuration automatically disables certain default Keycloak keys:

- **RSA-OAEP**: Default RSA encryption key
- **RS256**: Default RSA signing key

This ensures only the custom imported keys are active for OpenID4VCI operations.

### Extensible Credential Configuration

The Terraform setup is designed to be fully extensible. It automatically discovers and configures all credential definitions (`*.json` files) located in the `jsons/scopes/` directory.

To add a new credential type, simply create a new JSON file in this directory. Terraform will automatically create the corresponding client scope and associate it with the clients.

### SAML Identity Provider Features

The SAML identity provider configuration includes:

- **Mock SAML Provider**: Pre-configured for testing with mocksaml.com
- **User Attribute Mapping**: Automatic mapping of user attributes (email, firstName, lastName)
- **Security Configuration**: Signature validation and secure binding settings
- **Customizable**: Easy to modify for different SAML providers via JSON configuration

### Pre-authorized Code Lifespan

The realm is configured with a 120-second pre-authorized code lifespan for enhanced security.

## Troubleshooting

### Common Issues

1. **Connection Errors**: Ensure Keycloak is running and accessible at the specified URL
2. **Authentication Failures**: Verify admin credentials in `variables.tf`
3. **Key Import Failures**: Check if the JSON key files exist and are valid
4. **Permission Errors**: Ensure the admin user has sufficient privileges
5. **SAML IdP Issues**: Verify SAML provider configuration and certificate validity

### Debug Mode

Enable Terraform debug logging:

```bash
export TF_LOG=DEBUG
terraform apply
```

### Keycloak Logs

Check Keycloak server logs for detailed error information during deployment.

## Security Considerations

- **Admin Credentials**: Store sensitive credentials securely, consider using environment variables
- **Key Management**: Cryptographic keys should be stored securely and rotated regularly
- **Network Security**: Ensure Keycloak is not exposed to public networks without proper security measures
- **TLS**: In production, enable TLS and disable `tls_insecure_skip_verify`

## Production Deployment

For production environments:

1. **Use Environment Variables**: Set sensitive values via environment variables
2. **Enable TLS**: Configure proper SSL/TLS certificates
3. **Network Security**: Restrict access to Keycloak admin interface
4. **Monitoring**: Implement proper logging and monitoring
5. **Backup**: Regular backups of Keycloak data and Terraform state
