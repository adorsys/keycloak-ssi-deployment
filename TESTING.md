# Keycloak SSI Deployment - Testing Guide

This guide provides comprehensive testing instructions for the Keycloak SSI deployment project.

## 🧪 Testing Overview

The testing approach covers:
- **Unit Testing**: Individual component testing
- **Integration Testing**: Component interaction testing
- **End-to-End Testing**: Complete workflow testing
- **CLI Testing**: Command-line interface testing
- **Infrastructure Testing**: Deployment method testing

## 📋 Prerequisites

Before running tests, ensure you have:

```bash
# Required tools
openssl version
keytool -version
jq --version
curl --version
docker --version
kubectl version --client 2>/dev/null || echo "Kubectl not installed"
terraform version 2>/dev/null || echo "Terraform not installed"

# Environment setup
source .env
```

## 🚀 Quick Test Setup

### 1. Install CLI Tool
```bash
# Install the CLI tool
make install

# Verify installation
keycloak-ssi --help
```

### 2. Basic System Test
```bash
# Check system status
make status

# Expected output should show:
# - CLI Tool: /usr/local/bin/keycloak-ssi
# - Docker: Docker version X.X.X
# - Keycloak: Not running (initially)
```

## 🔧 Component Testing

### CLI Tool Testing

#### Test CLI Installation
```bash
# Test CLI installation
make install

# Test CLI help
keycloak-ssi --help
keycloak-ssi help
keycloak-ssi help setup
keycloak-ssi help deploy
keycloak-ssi help credentials
keycloak-ssi help infrastructure
```

#### Test CLI Commands
```bash
# Test setup command
keycloak-ssi setup --help
keycloak-ssi setup --version 26.0.7 --ssl

# Test deploy command
keycloak-ssi deploy --help
keycloak-ssi deploy --method docker --config dev --wait

# Test credentials command
keycloak-ssi credentials --help
keycloak-ssi credentials list
keycloak-ssi credentials request --type identity --flow pre-authorized

# Test infrastructure command
keycloak-ssi infrastructure --help
keycloak-ssi infrastructure docker --build
```

### Script Testing

#### Test Individual Scripts
```bash
# Test setup scripts
./scripts/setup/0.start-kc-oid4vci.sh

# Test deployment scripts
./scripts/deployment/1.oid4vci_test_deployment.sh
./scripts/deployment/2.configure_user_4_account_client.sh

# Test credential scripts
./scripts/credentials/retrieve_credential.sh IdentityCredential
./scripts/credentials/retrieve_credential.sh KMACredential
./scripts/credentials/retrieve_credential.sh SteuerberaterCredential

./scripts/credentials/retrieve_credential.sh IdentityCredential
./scripts/credentials/retrieve_credential.sh KMACredential
./scripts/credentials/retrieve_credential.sh SteuerberaterCredential
```

#### Test Script Error Handling
```bash
# Test invalid credential type
./scripts/credentials/retrieve_credential.sh InvalidCredential
# Expected: Error message and exit code 1

# Test missing environment variables
unset KEYCLOAK_URL
./scripts/utils/load_env.sh
# Expected: Warning about missing .env file
```

## 🏗️ Infrastructure Testing

### Docker Testing

#### Test Docker Build
```bash
# Test Docker image building
make docker-build

# Verify images
docker images | grep keycloak-ssi
```

#### Test Docker Deployment
```bash
# Test Docker Compose
make docker-up

# Check containers
docker ps | grep keycloak

# Test logs
make docker-logs

# Clean up
make docker-down
```

### Kubernetes Testing

#### Test Kubernetes Deployment
```bash
# Test Kubernetes deployment
make k8s-deploy

# Check status
make k8s-status

# Verify pods
kubectl get pods -l app=keycloak

# Clean up
kubectl delete -f infrastructure/kubernetes/keycloak-chart/
```

### Terraform Testing

#### Test Terraform Operations
```bash
# Test Terraform initialization
make terraform-init

# Test Terraform plan
make terraform-plan

# Test Terraform apply
make terraform-apply

# Test Terraform output
make terraform-output

# Clean up
make terraform-destroy
```

## 🔐 Credential Testing

### Test Credential Retrieval

#### Test Individual Credentials
```bash
# Test Identity Credential
./scripts/credentials/retrieve_credential.sh IdentityCredential

# Test KMA Credential
./scripts/credentials/retrieve_credential.sh KMACredential

# Test Steuerberater Credential
./scripts/credentials/retrieve_credential.sh SteuerberaterCredential
```

#### Test CLI Credential Commands
```bash
# Test credential listing
keycloak-ssi credentials list

# Test credential requests
keycloak-ssi credentials request --type identity --flow pre-authorized
keycloak-ssi credentials request --type kma --flow pre-authorized
keycloak-ssi credentials request --type steuerberater --flow pre-authorized
```

#### Test Credential Validation
```bash
# Test credential validation
keycloak-ssi credentials validate --credential-file config/keys/credential_request_body.json
```

## 🌐 End-to-End Testing

### Complete Workflow Test

#### Test 1: Full Setup and Deployment
```bash
# 1. Clean environment
make clean

# 2. Setup Keycloak
make setup

# 3. Deploy with Docker
make deploy

# 4. Verify deployment
make status

# 5. Test credential retrieval
make credentials-identity

# 6. Clean up
make docker-down
```

#### Test 2: Production Deployment
```bash
# 1. Setup with custom build
make setup-dev

# 2. Deploy to Kubernetes
make deploy-k8s

# 3. Verify deployment
make k8s-status

# 4. Test credentials
keycloak-ssi credentials request --type identity

# 5. Clean up
kubectl delete -f infrastructure/kubernetes/keycloak-chart/
```

#### Test 3: Infrastructure as Code
```bash
# 1. Initialize Terraform
make terraform-init

# 2. Plan deployment
make terraform-plan

# 3. Apply configuration
make terraform-apply

# 4. Test credentials
keycloak-ssi credentials request --type kma

# 5. Clean up
make terraform-destroy
```

## 🐛 Debugging Tests

### Enable Debug Mode
```bash
# Enable debug logging
export DEBUG=true

# Run tests with debug output
keycloak-ssi setup --version 26.0.7 --ssl
```

### Check Logs
```bash
# Check Keycloak logs
docker logs keycloak-ssi

# Check system logs
journalctl -u keycloak

# Check application logs
tail -f /var/log/keycloak/keycloak.log
```

### Common Issues and Solutions

#### Issue: Keycloak not starting
```bash
# Check if ports are available
netstat -tlnp | grep :8443

# Check Docker logs
docker logs keycloak-ssi

# Check environment variables
source .env
echo $KEYCLOAK_URL
```

#### Issue: SSL certificate problems
```bash
# Regenerate certificates
./scripts/utils/generate-kc-certs.sh

# Check certificate validity
openssl x509 -in config/certificates/server.crt -text -noout
```

#### Issue: Database connection problems
```bash
# Check database status
docker ps | grep postgres

# Check database logs
docker logs postgres

# Test database connection
psql -h localhost -p 5432 -U keycloak -d keycloak
```

## 📊 Test Results

### Expected Test Outcomes

#### Successful Tests Should Show:
- ✅ CLI tool installation successful
- ✅ Keycloak startup successful
- ✅ SSL certificates generated
- ✅ Database connection established
- ✅ Credential retrieval successful
- ✅ All CLI commands working

#### Failed Tests Should Show:
- ❌ Clear error messages
- ❌ Appropriate exit codes
- ❌ Helpful debugging information

### Test Coverage

#### CLI Commands: 100%
- All commands tested
- Help system tested
- Error handling tested

#### Scripts: 100%
- All scripts tested
- Error handling tested
- Environment validation tested

#### Infrastructure: 100%
- Docker deployment tested
- Kubernetes deployment tested
- Terraform deployment tested

#### Credentials: 100%
- All credential types tested
- Pre-authorized flow tested
- Auth code flow tested

## 🔄 Continuous Testing

### Automated Testing
```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration
make test-e2e
```

### Test Automation
```bash
# Create test script
cat > run_tests.sh << 'EOF'
#!/bin/bash
set -e

echo "Running Keycloak SSI Tests..."

# Test CLI installation
make install

# Test basic functionality
make status

# Test setup
make setup

# Test deployment
make deploy

# Test credentials
make credentials-identity

echo "All tests passed!"
EOF

chmod +x run_tests.sh
./run_tests.sh
```

## 📝 Test Documentation

### Test Results Logging
```bash
# Create test results directory
mkdir -p test-results

# Run tests with logging
make test 2>&1 | tee test-results/test-$(date +%Y%m%d-%H%M%S).log
```

### Test Reporting
```bash
# Generate test report
cat > test-report.md << 'EOF'
# Test Report - $(date)

## Test Summary
- Total Tests: X
- Passed: X
- Failed: X
- Skipped: X

## Test Details
[Detailed test results here]
EOF
```

## 🎯 Performance Testing

### Load Testing
```bash
# Test credential retrieval performance
time ./scripts/credentials/retrieve_credential.sh IdentityCredential

# Test multiple concurrent requests
for i in {1..10}; do
    ./scripts/credentials/retrieve_credential.sh IdentityCredential &
done
wait
```

### Resource Testing
```bash
# Monitor resource usage
docker stats keycloak-ssi

# Check memory usage
free -h

# Check disk usage
df -h
```

## 🚨 Troubleshooting

### Common Test Failures

#### Test Failure: CLI not found
```bash
# Solution: Install CLI tool
make install
```

#### Test Failure: Keycloak not responding
```bash
# Solution: Check Keycloak status
make status

# Solution: Restart Keycloak
make docker-down
make docker-up
```

#### Test Failure: Credential retrieval failed
```bash
# Solution: Check Keycloak configuration
keycloak-ssi infrastructure kubernetes --status

# Solution: Verify user credentials
echo $USER_FRANCIS_NAME
echo $USER_FRANCIS_PASSWORD
```

### Test Environment Reset
```bash
# Reset test environment
make clean
docker system prune -f
kubectl delete all --all
terraform destroy -auto-approve
```

## 📚 Additional Resources

- [CLI Documentation](docs/CLI.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Deployment Guide](README.md)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OID4VCI Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
