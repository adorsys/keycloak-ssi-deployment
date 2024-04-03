# Build the image
docker build -t keycloak-oidc-vci .

# Run the image
docker run -d -p 8080:8080 --name keycloak-oidc-vci keycloak-oidc-vci:latest
