#!/bin/bash

# Source common env variables
. load_env.sh

# Check if keystore exists and delete if it does
if [ ! -f "$FRANCIS_KEYSTORE_FILE" ]; then
# Generate the ECDSA Key
keytool \
  -genkeypair \
  -keyalg EC \
  -keysize 256 \
  -keystore "$FRANCIS_KEYSTORE_FILE" \
  -storepass "$FRANCIS_KEYSTORE_PASSWORD" \
  -alias "$FRANCIS_KEYSTORE_ECDSA_KEY_ALIAS" \
  -keypass "$FRANCIS_KEYSTORE_PASSWORD" \
  -storetype "$FRANCIS_KEYSTORE_TYPE" \
  -dname "CN=Francis Pouatcha, OU=Keycloak Competence Center, O=Adorsys Lab, L=Bangante, ST=West, C=Cameroon"
fi

# Extract Public Key in PEM Format
openssl ec -in "$FRANCIS_KEYSTORE_FILE" -passin pass:"$FRANCIS_KEYSTORE_PASSWORD" -pubout -outform der -out $TARGET_DIR/francis_pub.der

# Extract the hex representation of the DER file
hex=$(dd if=$TARGET_DIR/francis_pub.der bs=1 skip=$(expr $(wc -c < $TARGET_DIR/francis_pub.der) - 64) count=64 2>/dev/null | xxd -p | tr -d '\n')
# Extract X and Y (assuming P-256, 32 bytes each)
x_hex=${hex:0:64}
y_hex=${hex:64:64}

# Convert hex to base64 url safe, no padding
x_b64=$(echo $x_hex | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')
y_b64=$(echo $y_hex | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

# prepare the user key proof header
cat $WORK_DIR/user_key_proof_header.json | jq --arg x "$x_b64" --arg y "$y_b64" '.jwk.x = $x | .jwk.y = $y' > $TARGET_DIR/user_key_proof_header.json
