#!/bin/bash

# Script to generate JWKS (JSON Web Key Set) for the openid4vc-rest-api client
# This extracts the private key from the existing keystore and creates a complete JWKS

# Source common env variables
. ../load_env.sh

echo "Generating JWKS for openid4vc-rest-api client..."

# Check if the Francis keystore exists
if [ ! -f "$FRANCIS_KEYSTORE_FILE" ]; then
    echo "Error: Francis keystore not found at $FRANCIS_KEYSTORE_FILE"
    echo "Please run generate_user_key.sh first to create the keystore."
    exit 1
fi

# Extract private key from keystore
echo "Extracting private key from keystore..."
openssl pkcs12 -in "$FRANCIS_KEYSTORE_FILE" -nocerts -nodes -out $TARGET_DIR/francis_private_key.pem -passin pass:"$FRANCIS_KEYSTORE_PASSWORD"

# Extract public key in DER format
echo "Extracting public key..."
openssl ec -in "$FRANCIS_KEYSTORE_FILE" -passin pass:"$FRANCIS_KEYSTORE_PASSWORD" -pubout -outform der -out $TARGET_DIR/francis_pub.der

# Extract the hex representation of the DER file
hex=$(dd if=$TARGET_DIR/francis_pub.der bs=1 skip=$(expr $(wc -c < $TARGET_DIR/francis_pub.der) - 64) count=64 2>/dev/null | xxd -p | tr -d '\n')

# Extract X and Y (assuming P-256, 32 bytes each)
x_hex=${hex:0:64}
y_hex=${hex:64:64}

# Convert hex to base64 url safe, no padding
x_b64=$(echo $x_hex | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')
y_b64=$(echo $y_hex | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

# Extract private key (d parameter) from PEM
echo "Extracting private key component (d)..."
# Use openssl to extract the private key in hex format
# First, let's see the structure of the key
openssl ec -in $TARGET_DIR/francis_private_key.pem -text -noout > $TARGET_DIR/key_info.txt

# Extract the private key hex value (64 characters for P-256)
d_hex=$(grep -A 5 "priv:" $TARGET_DIR/key_info.txt | grep -v "priv:" | tr -d ' :\n' | head -c 64)

# Convert d to base64 url safe, no padding
d_b64=$(echo $d_hex | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

# Generate a key ID
kid="francis-key-1"

# Create the complete JWKS
echo "Creating JWKS..."
cat > $TARGET_DIR/openid4vc_rest_api_jwks.json << EOF
{
  "keys": [
    {
      "kty": "EC",
      "crv": "P-256",
      "x": "$x_b64",
      "y": "$y_b64",
      "d": "$d_b64",
      "kid": "$kid",
      "use": "sig",
      "alg": "ES256"
    }
  ]
}
EOF

echo "JWKS generated successfully!"
echo "File location: $TARGET_DIR/openid4vc_rest_api_jwks.json"
echo ""
echo "JWKS Content:"
cat $TARGET_DIR/openid4vc_rest_api_jwks.json | jq .
echo ""
echo "Note: This JWKS contains the private key (d parameter) and should be kept secure!"
