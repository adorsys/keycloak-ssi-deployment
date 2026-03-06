#!/usr/bin/env bash

set -euo pipefail

# This script generates a HAIP VC signing key and certificate for Keycloak,
# and bundles them into a PKCS#12 keystore that can be used by the
# java-keystore KeyProvider configured in import_kc_config.sh.
#
# Output:
#   - haip-root-ca.key / haip-root-ca.crt      (local test CA)
#   - haip-vc-signer.key / haip-vc-signer.crt (leaf, NOT self-signed)
#   - haip-vc-signer.p12                      (PKCS#12 keystore)
#
# The keystore path and password should then be referenced in .env as:
#   HAIP_VC_SIGNER_KEYSTORE_PATH=/home/ubuntu/adorsys/keycloak-ssi-deployment/config/haip-vc-signer.p12
#   HAIP_VC_SIGNER_KEYSTORE_PASSWORD=<same password used below>
#   HAIP_VC_SIGNER_KEY_ALIAS=haip-vc-signer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR"

P12_NAME="haip-vc-signer.p12"
P12_PATH="$OUT_DIR/$P12_NAME"
P12_PASS="${HAIP_VC_SIGNER_P12_PASSWORD:-haip_vc_signer_change_me}"

echo "Generating HAIP VC signing keystore in: $OUT_DIR"
echo "  PKCS#12: $P12_PATH"
echo "  Password: $P12_PASS"

cd "$OUT_DIR"

if command -v openssl >/dev/null 2>&1; then
  echo "Using openssl: $(command -v openssl)"
else
  echo "ERROR: openssl is required but not found in PATH."
  exit 1
fi

# 1) Root CA key + cert (self-signed root; leaf will NOT be self-signed)
if [ -f "haip-root-ca.key" ] || [ -f "haip-root-ca.crt" ]; then
  echo "haip-root-ca.{key,crt} already exist, skipping CA generation."
else
  echo "Generating HAIP root CA key and certificate ..."
  openssl genrsa -out haip-root-ca.key 4096

  openssl req -x509 -new -nodes -key haip-root-ca.key -sha256 -days 3650 \
    -subj "/C=DE/O=Adorsys/CN=Adorsys HAIP Test Root CA" \
    -out haip-root-ca.crt
fi

# 2) Leaf EC key (P-256, for ES256 signing)
if [ -f "haip-vc-signer.key" ]; then
  echo "haip-vc-signer.key already exists, skipping key generation."
else
  echo "Generating HAIP VC signer EC key (P-256) ..."
  openssl ecparam -name prime256v1 -genkey -noout -out haip-vc-signer.key
fi

# 3) CSR for the leaf
echo "Generating CSR for HAIP VC signer ..."
openssl req -new -key haip-vc-signer.key \
  -subj "/C=DE/O=Adorsys/CN=HAIP VC Signing Key" \
  -out haip-vc-signer.csr

# 4) Sign leaf with root CA (non-self-signed leaf)
cat > haip-vc-signer-ext.cnf <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo "Signing HAIP VC signer certificate with HAIP root CA ..."
openssl x509 -req -in haip-vc-signer.csr \
  -CA haip-root-ca.crt -CAkey haip-root-ca.key -CAcreateserial \
  -out haip-vc-signer.crt -days 365 -sha256 \
  -extfile haip-vc-signer-ext.cnf

# 5) Verify certificate chain and build PKCS#12 keystore
echo "Verifying certificate chain ..."
# Verify that the leaf certificate is properly signed by the root CA
if ! openssl verify -CAfile haip-root-ca.crt haip-vc-signer.crt >/dev/null 2>&1; then
  echo "ERROR: Certificate chain validation failed!"
  echo "The leaf certificate is not properly signed by the root CA."
  exit 1
fi
echo "✅ Certificate chain is valid"

echo "Building PKCS#12 keystore with certificate chain ..."
# Build a local chain file (leaf + root) and include the full chain in the PKCS#12.
# Keycloak's JavaKeystoreKeyProvider validates that the certificate chain is complete
# and anchored, so the trust anchor (root) must be present in the keystore.
# HAIP-6.1.1 requires that the trust anchor is NOT included in the x5c header, which
# we satisfy by filtering self-signed roots when constructing x5c (in SdJwtCredentialSigner),
# not by stripping the root from the keystore.
cat haip-vc-signer.crt haip-root-ca.crt > haip-vc-signer-chain.crt

# Use -certfile to explicitly add the root CA as an additional certificate in the chain
# This ensures OpenSSL properly stores them as a certificate chain
openssl pkcs12 -export \
  -inkey haip-vc-signer.key \
  -in haip-vc-signer.crt \
  -certfile haip-root-ca.crt \
  -name haip-vc-signer \
  -out "$P12_PATH" \
  -password "pass:$P12_PASS"

echo ""
echo "✅ HAIP VC signing keystore generated:"
echo "  - Keystore: $P12_PATH"
echo "  - Alias:    haip-vc-signer"
echo "  - Password: $P12_PASS"
echo ""
echo "Next steps:"
echo "  1) Set these in your .env:"
echo "       HAIP_VC_SIGNER_KEYSTORE_PATH=$P12_PATH"
echo "       HAIP_VC_SIGNER_KEYSTORE_PASSWORD=$P12_PASS"
echo "       HAIP_VC_SIGNER_KEY_ALIAS=haip-vc-signer"
echo "  2) Re-run config/import_kc_config.sh to provision the java-keystore provider."

