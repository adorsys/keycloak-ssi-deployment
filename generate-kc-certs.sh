#!/bin/bash

. load_env.sh

openssl req -newkey rsa:2048 -nodes \
  -keyout $KC_SERVER_KEY -x509 -days 3650 -out $KC_SERVER_CERT -config $WORK_DIR/cert-config.txt \
  -extensions v3_req
  
# Delete existing alias if it exists to avoid "already exists" error
keytool -delete -alias "$KEYCLOAK_HOSTNAME" -keystore "$KC_TRUST_STORE" -storepass "$KC_TRUST_STORE_PASS" 2>/dev/null || true

keytool -importcert -trustcacerts -noprompt -alias "$KEYCLOAK_HOSTNAME" -file "$KC_SERVER_CERT" -keystore "$KC_TRUST_STORE" -storepass "$KC_TRUST_STORE_PASS"