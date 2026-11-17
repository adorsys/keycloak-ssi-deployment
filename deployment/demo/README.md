# Standalone Compose stack

The repository-root `docker-compose.yml` starts a separate Keycloak instance,
its PostgreSQL database, a supplied mock-FE image, and Caddy. It is independent
of `keycloak-ssi.sh` and the upstream OAuth SIG submodule Compose file.

## Configure

Copy the example to the repository root and edit it:

```bash
cp deployment/demo/.env.demo.example .env.demo
```

Set strong database/admin passwords, the actual subdomain names, the mock-FE
image and its listening port, and `KEYCLOAK_KEYSTORE_HOST_ROOT`. That host path
must contain realm-named directories with the configured PKCS#12 files inside;
it is mounted read-only at `/opt/keycloak/data/keystores`. Set
`KEYCLOAK_TLS_HOST_DIR` to the existing SSI wrapper's `target` directory, which
must contain `keycloak-server.crt.pem` and `keycloak-server.key.pem`.

The mock-FE image must accept the `VITE_KEYCLOAK_*` and `VITE_OID4VC_*`
environment variables. The Keycloak client must allow the mock frontend's HTTPS
origin and redirect URIs.

## Keycloak image and providers

Keycloak runs directly from `quay.io/keycloak/keycloak:26.8.2`; Compose does not
build a Keycloak image. The repo's `providers/` directory is mounted read-only
into `/opt/keycloak/providers`. Compose uses the normal `start` command, not
`start --optimized`, so Keycloak can process the mounted providers at startup.
This follows Keycloak's [container guidance](https://www.keycloak.org/server/containers)
for starting a standard image when provider JARs are supplied at runtime.

Keycloak itself serves HTTPS on container port 8443 using the existing
`target/keycloak-server.crt.pem` and `target/keycloak-server.key.pem` files.
Caddy proxies to that HTTPS endpoint and trusts the mounted certificate; the
generated certificate has the `app` SAN used by Caddy for upstream validation.
Public HTTPS still terminates at the AWS ALB.

The Keycloak feature list and OID4VP managed-realm settings mirror the relevant
values from `deployment/keycloak/config.override.yaml`. The existing
`start_command` there is for the host-based Keycloak process: it enables HTTPS
inside Keycloak and references host certificate files. This Compose stack
terminates public HTTPS at the AWS ALB and re-encrypts the Caddy-to-Keycloak
hop. Keycloak uses its HTTPS listener, fixed public HTTPS hostname, and
forwarded-header handling.

## Configure and start

From the repository root:

```bash
docker compose --env-file .env.demo up -d
docker compose --env-file .env.demo ps
docker compose --env-file .env.demo logs -f keycloak caddy
```

Only Caddy publishes a host port (`8081` by default). Keycloak, PostgreSQL, and
the mock frontend are reachable only on the private Compose network. PostgreSQL
uses a named volume so restarting the stack preserves realm data. Do not use
`down -v` unless you intend to delete that data.

## HTTPS and AWS routing

Caddy listens for the configured hostnames over HTTP. Public TLS is terminated
by the existing AWS Application Load Balancer using its ACM certificate; the
ALB forwards to the EC2 host on `CADDY_HOST_PORT`. Create Route 53 aliases for
the Keycloak and frontend hostnames to that ALB and add ALB host rules pointing
both hostnames at a target group for the EC2 Caddy port. Restrict the EC2
security-group rule for that port to the ALB security group. This stack does not
route through the EC2 host's Nginx.

Keycloak is configured with its public HTTPS URL and `xforwarded` proxy headers,
while Caddy sets the public HTTPS scheme and port for its upstream requests. The
Compose stack does not expose Keycloak's HTTP port, database port, or frontend
port on the EC2 host.

The Keycloak client must allow the mock frontend's HTTPS origin and redirect
URIs. Configure those realm/client settings after the stack is reachable; DNS
and ALB routing alone do not configure Keycloak client origins.
