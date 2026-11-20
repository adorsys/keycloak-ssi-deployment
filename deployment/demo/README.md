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
image and its listening port, and `KEYCLOAK_KEYSTORE_HOST_ROOT`. The defaults
are `https://keycloak-demo-env.solutions.adorsys.com` and
`https://issuer-mock-fe.solutions.adorsys.com`; keep the hostnames in the root
`.env.demo` aligned with the AWS routing setup below. The mock frontend image is
published as `ghcr.io/adorsys-gis/keycloak-oid4vc-mock-fe:0.1.0`; its five
`VITE_*` runtime variables below are supported by the image. `MOCK_FE_PORT`
sets the container port used by Compose and Caddy, not a frontend runtime
setting. That host path
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
by the existing AWS Application Load Balancer using its ACM certificate. The
script `configure-demo-alb.sh` creates Route 53 aliases for both hostnames,
creates one target group for the EC2 Caddy port, adds HTTPS listener host rules,
and allows that port only from the ALB security group. It discovers the EC2
instance from the existing `keycloak-demo-targets` target group and leaves the
ALB's default action unchanged. This stack does not route through the EC2
host's Nginx.

The ALB and Caddy have separate routing roles. The ALB handles public TLS and
forwards only the two demo hostnames to Caddy over HTTP; its existing default
action continues handling other hostnames. Caddy uses the incoming hostname to
route requests to either the mock frontend or Keycloak. The Caddy-to-Keycloak
connection uses HTTPS, and Caddy explicitly trusts the mounted Keycloak
certificate. This keeps Keycloak's self-signed certificate on the private
Compose network, where it is validated by Caddy rather than by the ALB.

Preview the account, ALB, EC2 instance, and planned resources first:

```bash
./deployment/demo/configure-demo-alb.sh
```

Apply the Route 53, listener, target-group, and security-group changes only
after the preview is correct:

```bash
./deployment/demo/configure-demo-alb.sh --apply
```

The script defaults to AWS account `982081049921` in `eu-central-1`; set
`AWS_PROFILE` if you use a named profile. It requires AWS CLI and `jq`. The
Compose Caddy port (`CADDY_HOST_PORT`, default `8081`) must match the script's
`CADDY_PORT` (default `8081`). After routing is created, start the Compose stack
on the EC2 instance; the target health check uses Caddy's `/health` endpoint.

Keycloak is configured with its public HTTPS URL and `xforwarded` proxy headers,
while Caddy sets the public HTTPS scheme and port for its upstream requests. The
Compose stack does not expose Keycloak's HTTP port, database port, or frontend
port on the EC2 host.

The Keycloak client must allow the mock frontend's HTTPS origin and redirect
URIs. Configure those realm/client settings after the stack is reachable; DNS
and ALB routing alone do not configure Keycloak client origins.
