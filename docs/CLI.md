# Keycloak SSI CLI Documentation

## Overview

The Keycloak SSI CLI is a professional command-line tool for deploying and managing Keycloak with Self-Sovereign Identity (SSI) capabilities. It provides a unified interface for all Keycloak SSI operations.

## Installation

```bash
# Install the CLI tool
make install

# Verify installation
keycloak-ssi --help
```

## Commands

### Setup Command

Sets up Keycloak with OID4VCI capabilities.

```bash
keycloak-ssi setup [options]
```

**Options:**
- `--version VERSION`: Keycloak version to use (default: 26.0.7)
- `--branch BRANCH`: Git branch for custom builds (default: main)
- `--ssl`: Enable SSL/TLS configuration
- `--database TYPE`: Database type (postgres|h2) (default: postgres)
- `--help`: Show help message

**Examples:**
```bash
# Setup with official release
keycloak-ssi setup --version 26.0.7 --ssl

# Setup with custom build
keycloak-ssi setup --version 999.0.0-SNAPSHOT --branch datev/develop --ssl
```

### Deploy Command

Deploys and configures Keycloak.

```bash
keycloak-ssi deploy [options]
```

**Options:**
- `--config CONFIG`: Configuration profile (dev|release) (default: dev)
- `--method METHOD`: Deployment method (docker|kubernetes|terraform) (default: docker)
- `--realm REALM`: Realm name to create (default: oid4vc-vci)
- `--wait`: Wait for deployment to complete
- `--help`: Show help message

**Examples:**
```bash
# Deploy with Docker
keycloak-ssi deploy --method docker --config dev --wait

# Deploy to Kubernetes
keycloak-ssi deploy --method kubernetes --config release

# Deploy with Terraform
keycloak-ssi deploy --method terraform --realm my-realm
```

### Credentials Command

Manages verifiable credentials.

```bash
keycloak-ssi credentials <subcommand> [options]
```

**Subcommands:**
- `request`: Request verifiable credentials
- `list`: List available credential types
- `validate`: Validate a credential

**Options for `request`:**
- `--type TYPE`: Credential type (identity|kma|steuerberater) (default: identity)
- `--flow FLOW`: Authorization flow (pre-authorized|auth-code) (default: pre-authorized)

**Examples:**
```bash
# Request identity credential
keycloak-ssi credentials request --type identity --flow pre-authorized

# Request KMA credential with auth code flow
keycloak-ssi credentials request --type kma --flow auth-code

# List available credential types
keycloak-ssi credentials list

# Validate a credential
keycloak-ssi credentials validate --credential-file credential.json
```

### Infrastructure Command

Manages infrastructure components.

```bash
keycloak-ssi infrastructure <subcommand> [options]
```

**Subcommands:**
- `docker`: Docker operations
- `kubernetes`: Kubernetes operations
- `terraform`: Terraform operations

**Docker Options:**
- `--build`: Build Docker images
- `--up`: Start Docker services
- `--down`: Stop Docker services
- `--logs`: Show Docker logs

**Kubernetes Options:**
- `--deploy`: Deploy to Kubernetes
- `--delete`: Delete Kubernetes resources
- `--status`: Check Kubernetes status

**Terraform Options:**
- `--init`: Initialize Terraform
- `--plan`: Create Terraform plan
- `--apply`: Apply Terraform configuration
- `--destroy`: Destroy Terraform resources
- `--output`: Show Terraform outputs

**Examples:**
```bash
# Docker operations
keycloak-ssi infrastructure docker --build
keycloak-ssi infrastructure docker --up
keycloak-ssi infrastructure docker --logs

# Kubernetes operations
keycloak-ssi infrastructure kubernetes --deploy
keycloak-ssi infrastructure kubernetes --status

# Terraform operations
keycloak-ssi infrastructure terraform --init
keycloak-ssi infrastructure terraform --plan
keycloak-ssi infrastructure terraform --apply
```

## Environment Variables

The CLI tool uses environment variables for configuration. Create a `.env` file in the project root:

```bash
# Keycloak Configuration
KEYCLOAK_URL=https://localhost:8443
KC_BOOTSTRAP_ADMIN_USERNAME=admin
KC_BOOTSTRAP_ADMIN_PASSWORD=admin
KEYCLOAK_REALM=oid4vc-vci

# Database Configuration
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=password
KC_DB_NAME=keycloak
KC_DB_EXPOSED_PORT=5432

# SSL Configuration
KC_SERVER_CERT=config/certificates/server.crt
KC_SERVER_KEY=config/certificates/server.key
KC_TRUST_STORE=config/certificates/truststore.p12
KC_TRUST_STORE_PASS=changeit

# Keystore Configuration
KEYCLOAK_KEYSTORE_FILE=assets/keys/keystore.p12
KEYCLOAK_KEYSTORE_PASSWORD=changeit
KEYCLOAK_KEYSTORE_TYPE=PKCS12
KEYCLOAK_KEYSTORE_ECDSA_KEY_ALIAS=ecdsa-key
```

## Error Handling

The CLI tool provides comprehensive error handling:

- **Dependency checks**: Verifies required tools are installed
- **Environment validation**: Ensures required environment variables are set
- **Service health checks**: Monitors Keycloak availability
- **Graceful error messages**: Clear error descriptions and solutions

## Debug Mode

Enable debug mode for detailed logging:

```bash
export DEBUG=true
keycloak-ssi setup --version 26.0.7
```

## Examples

### Complete Setup and Deployment

```bash
# 1. Install CLI tool
make install

# 2. Setup Keycloak
keycloak-ssi setup --version 26.0.7 --ssl

# 3. Deploy with Docker
keycloak-ssi deploy --method docker --config dev --wait

# 4. Request credentials
keycloak-ssi credentials request --type identity --flow pre-authorized
```

### Production Deployment

```bash
# 1. Setup with custom build
keycloak-ssi setup --version 999.0.0-SNAPSHOT --branch datev/develop --ssl

# 2. Deploy to Kubernetes
keycloak-ssi deploy --method kubernetes --config release

# 3. Verify deployment
keycloak-ssi infrastructure kubernetes --status
```

### Infrastructure Management

```bash
# Build and deploy with Docker
keycloak-ssi infrastructure docker --build
keycloak-ssi infrastructure docker --up

# Deploy to Kubernetes
keycloak-ssi infrastructure kubernetes --deploy

# Manage with Terraform
keycloak-ssi infrastructure terraform --init
keycloak-ssi infrastructure terraform --plan
keycloak-ssi infrastructure terraform --apply
```

## Troubleshooting

### Common Issues

1. **CLI not found**: Run `make install` to install the CLI tool
2. **Permission denied**: Check file permissions and run with appropriate privileges
3. **Keycloak not starting**: Verify ports are available and dependencies are installed
4. **SSL certificate issues**: Regenerate certificates using the setup command
5. **Database connection**: Verify database credentials and connectivity

### Debug Information

```bash
# Check system status
make status

# Enable debug mode
export DEBUG=true

# Check CLI version
keycloak-ssi --version
```

## Best Practices

1. **Use environment files**: Store configuration in `.env` files
2. **Version control**: Keep configuration files in version control
3. **Backup**: Regularly backup keystores and configurations
4. **Security**: Use strong passwords and secure key management
5. **Monitoring**: Monitor service health and logs
6. **Testing**: Test deployments in development environments first
