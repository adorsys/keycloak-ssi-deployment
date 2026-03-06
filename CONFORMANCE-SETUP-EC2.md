# OID4VCI Conformance Setup: Local Service on EC2

This document describes the networking architecture and commands used to successfully run OID4VCI conformance tests against Keycloak on a remote EC2 instance.

## Architecture Overview

In this configuration, both **Keycloak** and the **OpenID Foundation Conformance Suite** run on the same **EC2 instance**. This simplifies communication between the test orchestration scripts and the suite.

- **Keycloak URL**: `https://keycloak-conformance.eudi-adorsys.com:8443`
- **Test Suite Dashboard**: `https://localhost.emobix.co.uk:9443`
- **Networking**: Your local browser accesses the EC2-hosted test suite via a secure SSH tunnel.

## 1. Local Configuration (Your Laptop)

### Update Hosts File
The test suite and Keycloak use `localhost.emobix.co.uk` for redirections. Point this to your local loopback.

- **Linux/Mac**: Add to `/etc/hosts`
- **Windows**: Add to `C:\Windows\System32\drivers\etc\hosts`

```text
127.0.0.1 localhost.emobix.co.uk
```

### Start SSH Local Tunnel
Run this in a dedicated terminal on your laptop to bridge port 9443 from EC2 to your local machine. We include **aggressive KeepAlive** settings (15s) to prevent the connection from being dropped by local firewalls or NAT gateways.

```bash
# Replace with your actual key path
ssh -i .ssh/remote-pc.pem \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o TCPKeepAlive=yes \
    -L 9443:localhost:9443 \
    ubuntu@keycloak-conformance.eudi-adorsys.com
```

## 2. Keycloak Configuration (EC2)

Ensure the OID4VCI client (e.g., `openid4vc-rest-api-jwt`) has the correct redirect URI allowed.

**File**: `conformance_auth_code_pk_jwt/openid4vc-rest-api-jwt.json`
```json
"redirectUris": [
    "https://localhost.emobix.co.uk:9443/test/a/keycloak-oid4vci-test/callback"
]
```

Apply the configuration:
```bash
./conformance_auth_code_pk_jwt/register_jwt_client.sh
```

## 3. Running a Test

1.  **Start the test suite** on your EC2 instance (usually via Docker).
2.  **Trigger the offer** from the EC2 instance:
    ```bash
    ./conformance_auth_code_pk_jwt/send_credential_offer_jwt.sh
    ```
3.  **Complete the flow**:
    - Open your browser to the URL displayed in the script output.
    - Log in to Keycloak.
    - Keycloak will redirect you to `localhost.emobix.co.uk:9443`, which resolves to your laptop, then travels through the tunnel back to the EC2 test suite.

## Why we did this
- **Bypassing Inbound Firewalls**: The EC2 instance doesn't need port 9443 open to the public internet because we use an SSH tunnel.
- **Latency & Reliability**: Running the suite near Keycloak makes the API exchanges between them faster and less prone to timeout.
- **Spec Compliance**: Some tests require the developer's browser to reach the test suite callback; the SSH tunnel + hosts file makes this work even across remote servers.
