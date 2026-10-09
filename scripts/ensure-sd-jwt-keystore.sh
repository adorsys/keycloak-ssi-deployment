#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
    cat <<'EOF'
Ensure that an existing PKCS12 signing key has the certificate chain required
by Keycloak 26.8 for dc+sd-jwt issuance.

Usage:
  ensure-sd-jwt-keystore.sh --keystore PATH --alias ALIAS \
    (--storepass PASSWORD | --storepass-file PATH)

The private signing key is preserved. If its certificate chain has fewer than
two certificates, the script creates a temporary development CA, signs a new
leaf certificate for the existing key, and imports the leaf and CA certificate.
EOF
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

log() {
    printf '[KEYSTORE] %s\n' "$*"
}

keystore_path=""
key_alias=""
storepass=""
storepass_file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keystore)
            [[ $# -ge 2 ]] || die "--keystore requires a value."
            keystore_path="$2"
            shift 2
            ;;
        --alias)
            [[ $# -ge 2 ]] || die "--alias requires a value."
            key_alias="$2"
            shift 2
            ;;
        --storepass)
            [[ $# -ge 2 ]] || die "--storepass requires a value."
            storepass="$2"
            shift 2
            ;;
        --storepass-file)
            [[ $# -ge 2 ]] || die "--storepass-file requires a value."
            storepass_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

[[ -n "$keystore_path" ]] || die "--keystore is required."
[[ -n "$key_alias" ]] || die "--alias is required."
[[ -f "$keystore_path" ]] || die "Keystore does not exist: $keystore_path"

if [[ -n "$storepass" && -n "$storepass_file" ]]; then
    die "Use either --storepass or --storepass-file, not both."
fi
if [[ -n "$storepass_file" ]]; then
    [[ -f "$storepass_file" ]] || die "Password file does not exist: $storepass_file"
    IFS= read -r storepass < "$storepass_file" || true
fi
[[ -n "$storepass" ]] || die "A non-empty keystore password is required."

for dependency in keytool openssl mktemp; do
    command -v "$dependency" >/dev/null 2>&1 || die "Required command is missing: $dependency"
done

keytool -list \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -alias "$key_alias" >/dev/null \
    || die "Cannot read private-key alias '$key_alias' from $keystore_path."

entry_description="$(keytool -list -v \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -alias "$key_alias")"
grep -q 'PrivateKeyEntry' <<< "$entry_description" \
    || die "Alias '$key_alias' is not a PrivateKeyEntry."

chain_pem="$(keytool -list -rfc \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -alias "$key_alias")"
chain_length="$(grep -c -- '-----BEGIN CERTIFICATE-----' <<< "$chain_pem" || true)"

if [[ "$chain_length" -ge 2 ]]; then
    log "Alias '$key_alias' already has a certificate chain of length $chain_length; no change needed."
    exit 0
fi

leaf_pem="$(keytool -exportcert -rfc \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -alias "$key_alias")"
leaf_subject="$(openssl x509 -noout -subject <<< "$leaf_pem" | sed 's/^subject=//')"
leaf_issuer="$(openssl x509 -noout -issuer <<< "$leaf_pem" | sed 's/^issuer=//')"

if [[ "$leaf_subject" != "$leaf_issuer" ]]; then
    die "Alias '$key_alias' has an incomplete non-self-signed certificate chain; refusing an automatic replacement."
fi

keystore_dir="$(cd "$(dirname "$keystore_path")" && pwd)"
keystore_name="$(basename "$keystore_path")"
backup_path="$keystore_dir/${keystore_name}.before-sd-jwt-chain.$(date -u +%Y%m%dT%H%M%SZ)"
cp -p "$keystore_path" "$backup_path"
chmod 600 "$backup_path"
log "Created backup: $backup_path"

temp_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$temp_dir"
}
trap cleanup EXIT

ca_alias="sdjwt_development_ca"
ca_keystore="$temp_dir/ca.p12"
ca_certificate="$temp_dir/ca.crt.pem"
signing_request="$temp_dir/signing.csr.pem"
signed_leaf="$temp_dir/signing.crt.pem"

keytool -genkeypair \
    -alias "$ca_alias" \
    -keyalg EC \
    -groupname secp256r1 \
    -sigalg SHA256withECDSA \
    -dname "CN=OID4VC Development Issuing CA,OU=SSI,O=Adorsys,C=DE" \
    -validity 3650 \
    -ext bc=ca:true \
    -ext ku=keyCertSign,cRLSign \
    -keystore "$ca_keystore" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -keypass "$storepass" >/dev/null

keytool -exportcert -rfc \
    -alias "$ca_alias" \
    -keystore "$ca_keystore" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -file "$ca_certificate" >/dev/null

keytool -certreq -rfc \
    -alias "$key_alias" \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -keypass "$storepass" \
    -file "$signing_request" >/dev/null

keytool -gencert -rfc \
    -alias "$ca_alias" \
    -keystore "$ca_keystore" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -keypass "$storepass" \
    -infile "$signing_request" \
    -outfile "$signed_leaf" \
    -validity 825 \
    -ext bc=ca:false \
    -ext ku=digitalSignature >/dev/null

ca_certificate_alias="${key_alias}_issuer_ca"
keytool -importcert -noprompt -trustcacerts \
    -alias "$ca_certificate_alias" \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -file "$ca_certificate" >/dev/null

if ! keytool -importcert -noprompt \
    -alias "$key_alias" \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -keypass "$storepass" \
    -file "$signed_leaf" >/dev/null; then
    cp -p "$backup_path" "$keystore_path"
    die "Could not import the signed leaf certificate; restored the backup."
fi

chmod 600 "$keystore_path"

upgraded_chain="$(keytool -list -rfc \
    -keystore "$keystore_path" \
    -storetype PKCS12 \
    -storepass "$storepass" \
    -alias "$key_alias")"
upgraded_length="$(grep -c -- '-----BEGIN CERTIFICATE-----' <<< "$upgraded_chain" || true)"
[[ "$upgraded_length" -ge 2 ]] || {
    cp -p "$backup_path" "$keystore_path"
    die "Certificate-chain validation failed; restored the backup."
}

log "Alias '$key_alias' now has a non-self-signed leaf and certificate chain length $upgraded_length."
log "The original private signing key was preserved."
