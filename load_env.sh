#!/bin/bash

# Source common env variables
. .env

# Using local properties
if [ -f "$WORK_DIR/../env/.env" ]; then
    echo "Using local properties from $WORK_DIR/../env/.env"
    . $WORK_DIR/../env/.env
    echo $KC_START
fi
