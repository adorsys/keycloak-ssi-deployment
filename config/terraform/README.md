# Keycloak SSI Deployment - Terraform Configuration

This directory contains Terraform configuration files for deploying and configuring Keycloak with OpenID4VCI (OpenID for Verifiable Credential Issuance) capabilities for Self-Sovereign Identity (SSI) applications.

## Overview

The Terraform configuration automates the setup of a Keycloak realm with:

- **Realm Configuration**: Creates a dedicated realm for OID4VCI operations
- **User Management**: Sets up test users with predefined credentials
- **Client Scopes**: Configures credential-specific client scopes for different credential types
- **Client Configuration**: Sets up the OID4VCI REST API client
- **Key Management**: Imports and configures cryptographic keys for signing and encryption

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
config/terraform/
├── main.tf                 # Main configuration file
├── provider.tf             # Keycloak provider configuration
├── variables.tf            # Input variables
├── modules/
│   ├── realm/             # Realm creation and configuration
│   ├── users/             # User management
│   ├── client_scopes/     # Client scope configuration
│   ├── clients/           # Client configuration
│   └── keys/              # Cryptographic key management
└── jsons/                 # JSON configuration files
    ├── keys/              # Key configuration files
    └── scopes/            # Client scope definitions
```

## Configuration

### Variables

The following variables can be customized in `variables.tf`:

| Variable         | Description                        | Default Value                      |
| ---------------- | ---------------------------------- | ---------------------------------- |
| `keycloak_url`   | Keycloak base URL                  | `https://localhost:8443`           |
| `admin_password` | Keycloak admin password            | `admin`                            |
| `realm`          | Keycloak realm name                | `oid4vc-vci`                       |
| `client_secret`  | Client secret for OID4VCI REST API | `uArydomqOymeF0tBrtipkPYujNNUuDlt` |

### Key Configuration

The keys module imports three types of cryptographic keys:

- **ECDSA Issuer Key**: For signing verifiable credentials
- **RSA Issuer Key**: Alternative signing key
- **RSA Encryption Key**: For encrypting sensitive data

## Usage

### 1. Initialize Terraform

```bash
cd config/terraform
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

This ensures only the custom imported keys are active for OID4VCI operations.

### Credential Types Supported

The configuration supports three main credential types:

- **SteuerberaterCredential**: Tax advisor credentials
- **IdentityCredential**: Identity verification credentials
- **KMACredential**:

### Pre-authorized Code Lifespan

The realm is configured with a 120-second pre-authorized code lifespan for enhanced security.

## Troubleshooting

### Common Issues

1. **Connection Errors**: Ensure Keycloak is running and accessible at the specified URL
2. **Authentication Failures**: Verify admin credentials in `variables.tf`
3. **Key Import Failures**: Check if the JSON key files exist and are valid
4. **Permission Errors**: Ensure the admin user has sufficient privileges

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
