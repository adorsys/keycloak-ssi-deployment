# Keycloak SSI Deployment Architecture

## Overview

The Keycloak SSI Deployment project is designed as a professional, CLI-ready tool for deploying and managing Keycloak with Self-Sovereign Identity (SSI) capabilities. The architecture follows modern DevOps practices with clear separation of concerns and modular design.

## Architecture Principles

1. **Modularity**: Clear separation between CLI, infrastructure, scripts, and configurations
2. **Scalability**: Support for multiple deployment methods (Docker, Kubernetes, Terraform)
3. **Maintainability**: Organized code structure with proper documentation
4. **Usability**: Professional CLI interface with comprehensive help and error handling
5. **Extensibility**: Easy to add new features and deployment methods

## Project Structure

```
keycloak-ssi-deployment/
├── cli/                          # CLI Tool Implementation
│   ├── bin/                      # Executable entry point
│   │   └── keycloak-ssi          # Main CLI executable
│   ├── lib/                      # Common functions and utilities
│   │   └── common.sh             # Shared functionality
│   └── commands/                 # Command implementations
│       ├── setup.sh              # Setup command
│       ├── deploy.sh             # Deploy command
│       ├── credentials.sh        # Credentials command
│       ├── infrastructure.sh     # Infrastructure command
│       └── help.sh               # Help command
├── infrastructure/               # Infrastructure as Code
│   ├── docker/                   # Docker configurations
│   │   ├── Dockerfile            # Main Docker image
│   │   ├── Dockerfile.oid4vc-dev # Development image
│   │   ├── docker-compose.yml    # Docker Compose configuration
│   │   └── .dockerignore         # Docker ignore file
│   ├── kubernetes/               # Kubernetes manifests
│   │   └── keycloak-chart/       # Helm chart for Keycloak
│   └── terraform/                # Terraform modules
│       ├── main.tf               # Main Terraform configuration
│       ├── provider.tf           # Provider configuration
│       ├── variables.tf         # Input variables
│       ├── modules/              # Terraform modules
│       └── providers/           # Custom providers
├── scripts/                      # Automation Scripts
│   ├── setup/                    # Setup and installation scripts
│   │   ├── 0.start-kc-oid4vci.sh # Keycloak startup script
│   │   └── setup-kc-oid4vci.sh  # Keycloak setup script
│   ├── deployment/               # Deployment scripts
│   │   ├── 1.oid4vci_test_deployment.sh # OID4VCI deployment
│   │   ├── 2.configure_user_4_account_client.sh # User configuration
│   │   └── import_kc_config.sh  # Config import script
│   ├── credentials/              # Credential management scripts
│   │   ├── 3.retrieve_IdentityCredential.sh # Identity credential
│   │   ├── 3.retrieve_KMACredential.sh # KMA credential
│   │   └── 3.retrieve_SteuerberaterCredential.sh # Steuerberater credential
│   └── utils/                    # Utility scripts
│       ├── generate-kc-certs.sh  # Certificate generation
│       ├── generate_keystore.sh   # Keystore generation
│       ├── generate_user_key.sh  # User key generation
│       ├── kc-stop.sh            # Keycloak stop script
│       ├── load_env.sh            # Environment loading
│       └── update_sdjwt_vct.sh   # SD-JWT update script
├── config/                       # Configuration Files
│   ├── keycloak/                 # Keycloak configurations
│   │   ├── keycloak-config-dev.json # Development config
│   │   ├── keycloak-config-release.json # Release config
│   │   ├── client-scope-config.json # Client scope config
│   │   ├── realm-attributes.json # Realm attributes
│   │   ├── saml-idp-config.json # SAML IDP config
│   │   ├── openid4vc-rest-api.json # OpenID4VC REST API
│   │   └── oid4vc-demo-public.json # OID4VC demo config
│   ├── keys/                     # Cryptographic keys
│   │   ├── issuer_key_ecdsa.json # ECDSA issuer key
│   │   ├── issuer_key_rsa.json   # RSA issuer key
│   │   ├── encryption_key_aes.json # AES encryption key
│   │   ├── encryption_key_rsa.json # RSA encryption key
│   │   └── signature_key_hmac.json # HMAC signature key
│   ├── certificates/              # SSL certificates
│   │   └── cert-config.txt       # Certificate configuration
│   └── credentials/              # Credential templates
│       ├── credential_request_body.json # Credential request
│       ├── user_key_proof_header.json # User key proof header
│       ├── user_key_proof_payload.json # User key proof payload
│       └── user_pub_jwk.json     # User public JWK
├── docs/                         # Documentation
│   ├── api/                      # API documentation
│   ├── deployment/               # Deployment guides
│   ├── development/              # Development guides
│   ├── CLI.md                   # CLI documentation
│   └── ARCHITECTURE.md           # This file
├── examples/                     # Usage Examples
│   ├── basic/                    # Basic examples
│   └── advanced/                 # Advanced examples
├── tests/                        # Test Suites
│   ├── unit/                     # Unit tests
│   ├── integration/               # Integration tests
│   └── e2e/                      # End-to-end tests
├── assets/                       # Static Assets
│   ├── keys/                     # Key files
│   │   └── kc_keystore.pkcs12   # Keycloak keystore
│   ├── certs/                    # Certificate files
│   └── templates/                # Template files
├── .env                          # Environment variables
├── Makefile                      # Build automation
└── README.md                     # Project documentation
```

## Component Architecture

### CLI Tool (`cli/`)

The CLI tool is the main interface for interacting with the system. It provides:

- **Unified Interface**: Single entry point for all operations
- **Command Structure**: Modular command system
- **Error Handling**: Comprehensive error handling and user feedback
- **Help System**: Built-in help and documentation
- **Environment Management**: Automatic environment variable loading

**Key Components:**
- `bin/keycloak-ssi`: Main executable
- `lib/common.sh`: Shared functions and utilities
- `commands/`: Individual command implementations

### Infrastructure (`infrastructure/`)

Infrastructure as Code components for different deployment methods:

#### Docker (`infrastructure/docker/`)
- **Dockerfile**: Main application image
- **Dockerfile.oid4vc-dev**: Development image with OID4VC features
- **docker-compose.yml**: Multi-container orchestration
- **.dockerignore**: Docker build context optimization

#### Kubernetes (`infrastructure/kubernetes/`)
- **keycloak-chart/**: Helm chart for Keycloak deployment
- **values.yaml**: Chart configuration values
- **templates/**: Kubernetes manifest templates

#### Terraform (`infrastructure/terraform/`)
- **main.tf**: Main Terraform configuration
- **provider.tf**: Provider configurations
- **variables.tf**: Input variable definitions
- **modules/**: Reusable Terraform modules
- **providers/**: Custom provider plugins

### Scripts (`scripts/`)

Automation scripts organized by functionality:

#### Setup Scripts (`scripts/setup/`)
- Keycloak installation and configuration
- SSL certificate generation
- Database setup

#### Deployment Scripts (`scripts/deployment/`)
- OID4VCI protocol configuration
- User and client setup
- Configuration import

#### Credential Scripts (`scripts/credentials/`)
- Verifiable credential requests
- Key binding operations
- Credential validation

#### Utility Scripts (`scripts/utils/`)
- Certificate generation
- Keystore management
- Environment utilities

### Configuration (`config/`)

Configuration files organized by component:

#### Keycloak Configurations (`config/keycloak/`)
- Realm configurations
- Client scope definitions
- SAML IDP configurations
- OpenID4VC API configurations

#### Cryptographic Keys (`config/keys/`)
- Issuer keys (ECDSA, RSA)
- Encryption keys (AES, RSA)
- Signature keys (HMAC)

#### Certificates (`config/certificates/`)
- SSL certificate configurations
- Certificate generation templates

#### Credentials (`config/credentials/`)
- Credential request templates
- User key proof configurations
- JWK templates

## Data Flow

### 1. Setup Phase
```
User → CLI → Setup Scripts → Keycloak Installation → SSL Setup → Database Setup
```

### 2. Deployment Phase
```
User → CLI → Deploy Scripts → Infrastructure → Keycloak Configuration → Service Ready
```

### 3. Credential Phase
```
User → CLI → Credential Scripts → Keycloak API → Verifiable Credentials
```

## Security Architecture

### Key Management
- **Issuer Keys**: ECDSA and RSA keys for credential signing
- **Encryption Keys**: AES and RSA keys for data encryption
- **User Keys**: ECDSA keys for user key binding
- **SSL Certificates**: TLS certificates for secure communication

### Authentication & Authorization
- **Admin Authentication**: Bootstrap admin credentials
- **User Authentication**: Keycloak user management
- **Client Authentication**: OAuth2/OIDC client credentials
- **SAML Integration**: SAML identity provider configuration

### Network Security
- **TLS Encryption**: All communications encrypted
- **Certificate Validation**: SSL certificate verification
- **Trust Store**: Certificate trust management

## Deployment Patterns

### 1. Development Deployment
- **Method**: Docker Compose
- **Database**: PostgreSQL
- **SSL**: Self-signed certificates
- **Configuration**: Development profiles

### 2. Production Deployment
- **Method**: Kubernetes
- **Database**: Managed PostgreSQL
- **SSL**: CA-signed certificates
- **Configuration**: Production profiles

### 3. Infrastructure Deployment
- **Method**: Terraform
- **Database**: Cloud-managed database
- **SSL**: ACME certificates
- **Configuration**: Environment-specific

## Monitoring & Observability

### Health Checks
- **Keycloak Health**: Process monitoring
- **Database Health**: Connection monitoring
- **SSL Health**: Certificate validation

### Logging
- **Application Logs**: Keycloak application logs
- **Access Logs**: HTTP request logs
- **Error Logs**: Error tracking and debugging

### Metrics
- **Performance Metrics**: Response times and throughput
- **Resource Metrics**: CPU, memory, and disk usage
- **Business Metrics**: Credential issuance rates

## Scalability Considerations

### Horizontal Scaling
- **Load Balancing**: Multiple Keycloak instances
- **Database Scaling**: Read replicas and connection pooling
- **Caching**: Redis for session and token caching

### Vertical Scaling
- **Resource Allocation**: CPU and memory optimization
- **JVM Tuning**: Java heap and garbage collection
- **Database Tuning**: Query optimization and indexing

## Disaster Recovery

### Backup Strategy
- **Configuration Backup**: Realm and client configurations
- **Database Backup**: Regular database backups
- **Key Backup**: Cryptographic key backup

### Recovery Procedures
- **Configuration Recovery**: Import from backup
- **Database Recovery**: Point-in-time recovery
- **Key Recovery**: Key restoration procedures

## Future Enhancements

### Planned Features
- **Multi-tenant Support**: Multiple realm management
- **Advanced Monitoring**: Prometheus and Grafana integration
- **CI/CD Integration**: Automated deployment pipelines
- **Plugin System**: Extensible command system

### Architecture Evolution
- **Microservices**: Service decomposition
- **Event-driven**: Asynchronous processing
- **API Gateway**: Centralized API management
- **Service Mesh**: Advanced networking
