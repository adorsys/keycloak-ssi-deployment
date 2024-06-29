#!/bin/bash

# Source common env variables
. .env

# Stop if CREDENTIAL_ACCESS_TOKEN is not retrieved
if [ -z "$CREDENTIAL_ACCESS_TOKEN" ]; then
    echo "Generating key proof requires a credential access token, env: CREDENTIAL_ACCESS_TOKEN"
    exit 1
fi

# The proof timestamp
iat=$(date +%s)
# Compute the sha256 of the credential access token and use it as a c_nonce.
nonce=$(echo -n "$CREDENTIAL_ACCESS_TOKEN" | openssl dgst -sha256 -binary | openssl base64 | tr -d '=' | tr '/+' '_-')

less $WORK_DIR/user_key_proof_payload.json | jq --argjson iat $iat --arg nonce "$nonce" '.iat = $iat | .nonce=$nonce' > $TARGET_DIR/user_key_proof_payload.json

KEY_PROOF_HEADER_BASE64URL=$(openssl base64 -in $TARGET_DIR/user_key_proof_header.json | tr '+/' '-_' | tr -d '=' | tr -d '\n')
KEY_PROOF_PAYLOAD_BASE64URL=$(openssl base64 -in $TARGET_DIR/user_key_proof_payload.json | tr '+/' '-_' | tr -d '=' | tr -d '\n')

SIGN_INPUT=$(echo -n $KEY_PROOF_HEADER_BASE64URL.$KEY_PROOF_PAYLOAD_BASE64URL)

openssl pkcs12 -in "$FRANCIS_KEYSTORE_FILE" -nocerts -nodes -out $TARGET_DIR/francis_private_key.pem -passin pass:"$FRANCIS_KEYSTORE_PASSWORD"
echo -n $SIGN_INPUT | openssl dgst -sha256 -sign $TARGET_DIR/francis_private_key.pem -out $TARGET_DIR/signature.der

# Extract R and S values from the DER-encoded signature
R_HEX=$(openssl asn1parse -inform DER -in $TARGET_DIR/signature.der | grep -A 1 'INTEGER' | head -n 1 | awk '{print $7}' | tr -d ':')
S_HEX=$(openssl asn1parse -inform DER -in $TARGET_DIR/signature.der | grep -A 1 'INTEGER' | tail -n 1 | awk '{print $7}' | tr -d ':')

#openssl asn1parse -inform DER -in $TARGET_DIR/signature.der
#echo "R_HEX: " $R_HEX
#echo "S_HEX: " $S_HEX
#
#dd if=$TARGET_DIR/signature.der bs=1 skip=$((4)) count=32 of=$TARGET_DIR/r.bin
#dd if=$TARGET_DIR/signature.der bs=1 skip=$((38)) count=32 of=$TARGET_DIR/s.bin

# Concatenate R and S
#cat $TARGET_DIR/r.bin $TARGET_DIR/s.bin > $TARGET_DIR/signature_concat.bin

# Base64url encode the concatenated R and S
#openssl base64 -in $TARGET_DIR/signature_concat.bin -e -A | tr '+/' '-_' | tr -d '=' > $TARGET_DIR/signature.b64

KEY_PROOF_SIGN_BASE64URL=$(echo $R_HEX$S_HEX | xxd -r -p | openssl base64 -e -A | tr '+/' '-_' | tr -d '=' | tr -d '\n')

USER_KEY_PROOF=$(echo -n $KEY_PROOF_HEADER_BASE64URL.$KEY_PROOF_PAYLOAD_BASE64URL.$KEY_PROOF_SIGN_BASE64URL)

echo "USER_KEY_PROOF: " $USER_KEY_PROOF
