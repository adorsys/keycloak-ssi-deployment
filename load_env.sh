#!/bin/bash

# Source common env variables if they exist
if [ -f "$WORK_DIR/.env" ]; then
    . "$WORK_DIR/.env"
fi

# Using local properties
if [ -f "$WORK_DIR/../env/.env" ]; then
    echo "Using local properties from $WORK_DIR/../env/.env"
    . $WORK_DIR/../env/.env
    echo $KC_START
fi
