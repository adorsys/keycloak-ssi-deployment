#!/bin/sh

# Start Keycloak
cd $KEYCLOAK_INSTALL_DIR
exec bin/kc.sh $START_COMMAND $KC_DB_OPTS --features=oid4vc-vci,oid4vc-vpauth
