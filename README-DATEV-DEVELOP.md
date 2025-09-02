# Keycloak OID4VCI - datev/develop Branch Image

This setup builds Docker images from the `datev/develop` branch of the `adorsys/keycloak-oid4vc` repository with OID4VP Auth and OID4VCI features.

## Overview

- **Dockerfile**: `Dockerfile.datev-develop` - Multi-stage build with non-privileged user
- **CI/CD**: GitHub Actions workflow that builds and pushes to GHCR automatically
- **Branch**: Builds from `adorsys/keycloak-oid4vc:datev/develop`
- **Features**: `oid4vc-vpauth,oid4vc-vci` (built into image)

## Available Images

Images are automatically built and pushed to GitHub Container Registry (GHCR):

- `ghcr.io/adorsys/datev-oid4vp-auth:datev-develop-<commit-sha>`

The image is tagged with the branch name and short commit SHA for deployment automation.

## Usage

### Pull and Run

```bash
# Pull the image (replace <commit-sha> with actual SHA)
docker pull ghcr.io/adorsys/datev-oid4vp-auth:datev-develop-<commit-sha>

# Run the container
docker run -d \
  --name keycloak-oid4vp-auth \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  ghcr.io/adorsys/datev-oid4vp-auth:datev-develop-<commit-sha>
```

### Build Locally

```bash
# Build the image locally
docker build -f Dockerfile.datev-develop -t datev-oid4vp-auth:local .

# Run locally built image
docker run -d \
  --name keycloak-oid4vp-auth \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  datev-oid4vp-auth:local
```

## Environment Variables

| Variable                  | Description    | Default |
| ------------------------- | -------------- | ------- |
| `KEYCLOAK_ADMIN`          | Admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password | `admin` |

## CI/CD

The GitHub Actions workflow (`datev-oid4vp-auth-artifact.yml`) is triggered manually and:

- Builds the project when manually executed
- Pushes images to GHCR with branch-commit SHA tagging
- Enables deployment automation

## Security

- Runs as non-privileged user (`keycloak`)
- Minimal base image (OpenJDK 17 slim)
- Multi-stage build for reduced attack surface

## Access

- **Admin Console**: http://localhost:8080
- **Admin Username**: admin
- **Admin Password**: admin (change in production)
