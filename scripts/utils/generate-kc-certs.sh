#!/bin/bash

. scripts/utils/load_env.sh

openssl req -newkey rsa:2048 -nodes \
  -keyout $KC_SERVER_KEY -x509 -days 3650 -out $KC_SERVER_CERT -config $WORK_DIR/config/certificates/cert-config.txt \
  -extensions v3_req
  
keytool -importcert -trustcacerts -noprompt -alias localhost -file $KC_SERVER_CERT -keystore $KC_TRUST_STORE -storepass $KC_TRUST_STORE_PASS