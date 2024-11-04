#!/bin/bash

. load_env.sh

openssl req -newkey rsa:2048 -nodes \
  -keyout $KC_SERVER_KEY -x509 -days 3650 -out $KC_SERVER_CERT -config $WORK_DIR/cert-config.txt
  
keytool -importcert -trustcacerts -noprompt -alias localhost -file $KC_SERVER_CERT -keystore $KC_TRUST_STORE -storepass $KC_TRUST_STORE_PASS