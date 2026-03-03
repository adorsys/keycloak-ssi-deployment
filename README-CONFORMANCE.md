# FAPI Conformance Setup (AWS + Local Tunnel)

This document summarizes the setup used to pass FAPI 2.0 TLS conformance tests by bypassing Ngrok's cipher restrictions.

## The Problem
FAPI 2.0 requires strict TLS cipher suites (e.g., AES-GCM). Ngrok's free HTTP tunnels accept **ChaCha20** at their edge, which is forbidden by FAPI, leading to mandatory test failures.

## The Solution
We use an **AWS EC2 instance** as a raw TCP gateway. Traffic is tunneled to your local machine via **SSH Reverse Port Forwarding**, allowing your local Keycloak to terminate the TLS connection with custom, compliant ciphers.

---

## 1. Local Configuration

### Environment (`.env`)
The following variables were updated to point to the custom domain and enforce strict ciphers:
```bash
KEYCLOAK_HOSTNAME=keycloak-conformance.eudi-adorsys.com
KEYCLOAK_EXTERNAL_ADDR=https://keycloak-conformance.eudi-adorsys.com:8443

# FAPI Compliant Start Command
KC_START="... --https-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
```

### Certificates
Run `./generate-kc-certs.sh` whenever you change the domain. The configuration is in `cert-config.txt`.

---

## 2. AWS EC2 Configuration (One-time)

### Security Group
- Inbound Rule: **TCP 8443** allowed from **0.0.0.0/0**.

### SSH Daemon (`/etc/ssh/sshd_config`)
- `GatewayPorts yes` must be set to allow the public internet to reach the tunnel.
- Restart SSH: `sudo systemctl restart ssh`.

---

## 3. Daily Workflow

1.  **Start Local Keycloak**:
    ```bash
    ./0.start-kc-oid4vci.sh
    ```

2.  **Start SSH Tunnel (Local Terminal)**:
    ```bash
    ssh -i .ssh/remote-pc.pem -R 0.0.0.0:8443:localhost:8443 ubuntu@keycloak-conformance.eudi-adorsys.com
    ```

3.  **Run Conformance Test**:
    - URL: `https://keycloak-conformance.eudi-adorsys.com:8443/realms/oid4vc-vci`
    - Trust: Upload `target/keycloak-server.crt.pem` to the Conformance Suite.
