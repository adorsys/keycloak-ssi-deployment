#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

WORK_DIR="${WORK_DIR:-$PWD}"
TARGET_DIR="${TARGET_DIR:-$WORK_DIR/target}"
source "$WORK_DIR/load_env.sh"

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Generate self-signed server certificate if missing
# ---------------------------------------------------------------------------
if [[ ! -f "$KC_SERVER_KEY" || ! -f "$KC_SERVER_CERT" ]]; then
    log "Generating self-signed server certificate..."
    openssl req -newkey rsa:2048 -nodes \
        -keyout "$KC_SERVER_KEY" -x509 -days 3650 \
        -out "$KC_SERVER_CERT" -config "$WORK_DIR/src/utils/crypto/cert-config.txt" \
        -extensions v3_req
else
    log "Server key/certificate already exist. Skipping generation."
fi

# ---------------------------------------------------------------------------
# Import server certificate into truststore if missing
# ---------------------------------------------------------------------------
if [[ ! -f "$KC_TRUST_STORE" ]]; then
    log "Importing server certificate into trust store..."
    keytool -importcert -trustcacerts -noprompt \
        -alias localhost \
        -file "$KC_SERVER_CERT" \
        -keystore "$KC_TRUST_STORE" \
        -storepass "$KC_TRUST_STORE_PASS"
else
    log "Trust store already exists. Skipping import."
fi

log "Certificate setup completed."
