# Keycloak SSI Deployment

<p align="center">
  <img src="assets/banner.png" alt="Keycloak SSI Banner" width="800"/>
</p>

<p align="center">
  <strong>A professional CLI tool for deploying and managing Keycloak with Self-Sovereign Identity (SSI) capabilities using OpenID for Verifiable Credential Issuance (OID4VCI).</strong>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-documentation">Documentation</a> •
  <a href="#-contributing">Contributing</a>
</p>

## ✨ Features

- **Automated Deployment**: Single-command setup and deployment of Keycloak with SSI.
- **Multiple Environments**: Supports Docker, Kubernetes, and Terraform for local, staging, and production.
- **OID4VCI Ready**: Pre-configured for Verifiable Credential Issuance.
- **Extensible**: Easily customize and extend with new features.
- **Secure**: Includes SSL/TLS support and secure defaults.

## 🚀 Quick Start

```bash
# Install the CLI tool
make install

# Quick setup and deployment
make quickstart

# Or step by step
make setup
make deploy
```

## 📁 Project Structure

```
keycloak-ssi-deployment/
├── cli/                          # CLI tool implementation
│   ├── bin/                      # CLI executable
│   ├── lib/                      # Common functions
│   └── commands/                 # Command implementations
├── infrastructure/               # Infrastructure as Code
│   ├── docker/                   # Docker configurations
│   ├── kubernetes/              # Kubernetes manifests
│   └── terraform/                # Terraform modules
├── scripts/                      # Automation scripts
│   ├── setup/                    # Setup scripts
│   ├── deployment/               # Deployment scripts
│   ├── credentials/              # Credential management
│   └── utils/                    # Utility scripts
├── config/                       # Configuration files
│   ├── keycloak/                 # Keycloak configurations
│   ├── keys/                     # Cryptographic keys
│   ├── certificates/             # SSL certificates
│   └── credentials/              # Credential templates
├── docs/                         # Documentation
├── examples/                     # Usage examples
├── tests/                        # Test suites
└── assets/                       # Static assets
```

## 🛠️ Installation

### Prerequisites

- **OpenSSL**: For certificate generation
- **Keytool**: Java key management utility
- **jq**: JSON processor
- **curl**: HTTP client
- **Docker**: Container runtime (optional)
- **Kubectl**: Kubernetes client (optional)
- **Terraform**: Infrastructure as Code (optional)

### Install CLI Tool

```bash
# Clone the repository
git clone <repository-url>
cd keycloak-ssi-deployment

# Install the CLI tool
make install

# Verify installation
keycloak-ssi --help
```

## 🎯 Usage

### CLI Commands

#### Setup Keycloak
```bash
# Setup with official Keycloak release
keycloak-ssi setup --version 26.0.7 --ssl

# Setup with custom build
keycloak-ssi setup --version 999.0.0-SNAPSHOT --branch datev/develop --ssl
```

#### Deploy Keycloak
```bash
# Deploy with Docker
keycloak-ssi deploy --method docker --config dev --wait

# Deploy to Kubernetes
keycloak-ssi deploy --method kubernetes --config release

# Deploy with Terraform
keycloak-ssi deploy --method terraform --realm oid4vc-vci
```

#### Manage Credentials
```bash
# Request identity credential
keycloak-ssi credentials request --type identity --flow pre-authorized

# Request KMA credential
keycloak-ssi credentials request --type kma --flow auth-code

# List available credential types
keycloak-ssi credentials list
```

#### Infrastructure Management
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

### Makefile Commands

```bash
# Setup and deployment
make setup                    # Setup Keycloak
make deploy                   # Deploy with Docker
make quickstart              # Complete setup and deployment

# Infrastructure
make docker-build            # Build Docker images
make docker-up              # Start Docker services
make k8s-deploy             # Deploy to Kubernetes
make terraform-apply        # Apply Terraform configuration

# Credentials
make credentials-identity    # Request identity credential
make credentials-kma        # Request KMA credential
make credentials-list       # List credential types

# Development
make test                   # Run tests
make lint                   # Run linting
make clean                  # Clean up files
make status                 # Check system status
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with the following variables:

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

## 🏗️ Architecture

### Components

1. **CLI Tool**: Professional command-line interface
2. **Infrastructure**: Docker, Kubernetes, and Terraform configurations
3. **Scripts**: Automated setup and deployment scripts
4. **Configurations**: Keycloak realm and client configurations
5. **Credentials**: Verifiable credential templates and examples

### Deployment Options

- **Docker**: Local development and testing
- **Kubernetes**: Production deployments
- **Terraform**: Infrastructure automation

## 📚 Documentation

- [API Documentation](docs/api/)
- [Deployment Guide](docs/deployment/)
- [Development Guide](docs/development/)

## 🧪 Testing

```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration
make test-e2e
```

## 🔍 Troubleshooting

### Common Issues

1. **Keycloak not starting**: Check if ports are available
2. **SSL certificate issues**: Regenerate certificates
3. **Database connection**: Verify database credentials
4. **Permission issues**: Check file permissions

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true
keycloak-ssi setup --version 26.0.7
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Run linting: `make lint`
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/keycloak-ssi-deployment/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/keycloak-ssi-deployment/discussions)

## 🎉 Acknowledgments

- Keycloak team for the excellent identity management platform
- OpenID Foundation for the OID4VCI specification
- Contributors and community members
