#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <output-dir> <issuer-keystore> <store-password> <key-alias> <ca-alias>" >&2
  exit 1
fi

output_dir="$1"
issuer_keystore="$2"
store_password="$3"
key_alias="$4"
ca_alias="$5"

mkdir -p "$output_dir"

ca_key="$output_dir/mdoc-iaca.key.pem"
ca_cert_pem="$output_dir/mdoc-iaca.crt.pem"
ca_cert_der="$output_dir/mdoc-iaca.crt.der"
leaf_csr="$output_dir/mdoc-document-signer.csr.pem"
leaf_cert_pem="$output_dir/mdoc-document-signer.crt.pem"
leaf_extensions="$output_dir/mdoc-document-signer.extensions.cnf"

keytool_en() {
  keytool -J-Duser.language=en -J-Duser.country=US "$@"
}

[[ -f "$issuer_keystore" ]] || {
  echo "Issuer keystore does not exist: $issuer_keystore" >&2
  exit 1
}

keytool_en -list \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -alias "$key_alias" >/dev/null

chain_length="$(keytool_en -list -v \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -alias "$key_alias" \
  | sed -n 's/^Certificate chain length: //p' \
  | head -n 1)"

if [[ "$chain_length" =~ ^[2-9][0-9]*$ ]] \
    && keytool_en -list \
      -keystore "$issuer_keystore" \
      -storetype PKCS12 \
      -storepass "$store_password" \
      -alias "$ca_alias" >/dev/null 2>&1; then
  keytool_en -exportcert -rfc \
    -keystore "$issuer_keystore" \
    -storetype PKCS12 \
    -storepass "$store_password" \
    -alias "$ca_alias" \
    -file "$ca_cert_pem" >/dev/null
  keytool_en -exportcert -rfc \
    -keystore "$issuer_keystore" \
    -storetype PKCS12 \
    -storepass "$store_password" \
    -alias "$key_alias" \
    -file "$leaf_cert_pem" >/dev/null
  openssl x509 -in "$ca_cert_pem" -outform DER -out "$ca_cert_der"
  openssl verify -CAfile "$ca_cert_pem" "$leaf_cert_pem" >/dev/null
  echo "Reusing the existing CA-issued mDoc document-signer chain."
  exit 0
fi

if [[ ! -f "$ca_key" || ! -f "$ca_cert_pem" ]]; then
  echo "Generating a local development mDoc IACA..."
  openssl ecparam -name prime256v1 -genkey -noout -out "$ca_key"
  chmod 600 "$ca_key"
  openssl req -new -x509 -sha256 -days 3650 \
    -key "$ca_key" \
    -subj "/C=DE/O=adorsys local development/CN=Local mDoc IACA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash" \
    -out "$ca_cert_pem"
fi
chmod 600 "$ca_key"

openssl x509 -in "$ca_cert_pem" -outform DER -out "$ca_cert_der"

printf '%s\n' \
  '[mdoc_document_signer]' \
  'basicConstraints=critical,CA:FALSE' \
  'keyUsage=critical,digitalSignature' \
  'subjectKeyIdentifier=hash' \
  'authorityKeyIdentifier=keyid,issuer' > "$leaf_extensions"

echo "Replacing the self-signed certificate on '$key_alias' with a CA-issued document-signer certificate..."
keytool_en -certreq \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -keypass "$store_password" \
  -alias "$key_alias" \
  -file "$leaf_csr"

openssl x509 -req -sha256 -days 825 \
  -in "$leaf_csr" \
  -CA "$ca_cert_pem" \
  -CAkey "$ca_key" \
  -CAcreateserial \
  -extfile "$leaf_extensions" \
  -extensions mdoc_document_signer \
  -out "$leaf_cert_pem"

if keytool_en -list \
    -keystore "$issuer_keystore" \
    -storetype PKCS12 \
    -storepass "$store_password" \
    -alias "$ca_alias" >/dev/null 2>&1; then
  keytool_en -delete \
    -keystore "$issuer_keystore" \
    -storetype PKCS12 \
    -storepass "$store_password" \
    -alias "$ca_alias"
fi

keytool_en -importcert -noprompt -trustcacerts \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -alias "$ca_alias" \
  -file "$ca_cert_pem"

keytool_en -importcert -noprompt -trustcacerts \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -keypass "$store_password" \
  -alias "$key_alias" \
  -file "$leaf_cert_pem"

openssl verify -CAfile "$ca_cert_pem" "$leaf_cert_pem" >/dev/null

chain_length="$(keytool_en -list -v \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -alias "$key_alias" \
  | sed -n 's/^Certificate chain length: //p' \
  | head -n 1)"
if [[ ! "$chain_length" =~ ^[2-9][0-9]*$ ]]; then
  echo "The mDoc document-signer certificate chain was not installed correctly." >&2
  exit 1
fi

echo "Installed a CA-issued mDoc document-signer chain (length $chain_length)."
echo "Local mDoc IACA trust anchor: $ca_cert_der"
