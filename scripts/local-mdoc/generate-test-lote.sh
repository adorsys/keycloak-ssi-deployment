#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <output-dir> <issuer-keystore> <store-password> <key-alias> <provider-id>" >&2
  exit 1
fi

output_dir="$1"
issuer_keystore="$2"
store_password="$3"
key_alias="$4"
provider_id="$5"

mkdir -p "$output_dir"

lote_key="$output_dir/lote-signing.key.pem"
lote_cert_pem="$output_dir/lote-signing.crt.pem"
lote_cert_der="$output_dir/lote-signing.crt.der"
issuer_cert_der="$output_dir/mdoc-issuer.crt.der"
trust_list="$output_dir/pid-providers.jwt"

if [[ ! -f "$lote_key" || ! -f "$lote_cert_pem" ]]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 \
    -subj "/CN=Local PID LoTE Signer/O=adorsys development" \
    -keyout "$lote_key" -out "$lote_cert_pem"
fi

openssl x509 -in "$lote_cert_pem" -outform DER -out "$lote_cert_der"
keytool -exportcert -rfc \
  -keystore "$issuer_keystore" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -alias "$key_alias" \
  | openssl x509 -outform DER -out "$issuer_cert_der"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

lote_x5c="$(openssl base64 -A -in "$lote_cert_der")"
issuer_x5c="$(openssl base64 -A -in "$issuer_cert_der")"
issued_at="$(date -u -d '1 minute ago' '+%Y-%m-%dT%H:%M:%SZ')"
next_update="$(date -u -d '30 days' '+%Y-%m-%dT%H:%M:%SZ')"

header="$(jq -cn --arg cert "$lote_x5c" --arg sigT "$issued_at" '{typ:"trustlist+jwt",alg:"RS256",sigT:$sigT,x5c:[$cert]}')"
payload="$(jq -cn \
  --arg provider "$provider_id" \
  --arg certificate "$issuer_x5c" \
  --arg loteCertificate "$lote_x5c" \
  --arg issuedAt "$issued_at" \
  --arg nextUpdate "$next_update" \
  '{LoTE:{ListAndSchemeInformation:{LoTEVersionIdentifier:1,LoTESequenceNumber:1,LoTEType:"http://uri.etsi.org/19602/LoTEType/EUPIDProvidersList",SchemeOperatorName:[{lang:"en",value:"adorsys local development"}],SchemeOperatorAddress:{SchemeOperatorPostalAddress:[{lang:"en",StreetAddress:"Local development",Country:"DE"}],SchemeOperatorElectronicAddress:[{lang:"en",uriValue:"mailto:local@example.invalid"}]},SchemeName:[{lang:"en",value:"Local PID Providers List"}],SchemeInformationURI:[{lang:"en",uriValue:"https://localhost:9443/"},{lang:"en",uriValue:"https://localhost:9443/history/"}],StatusDeterminationApproach:"http://uri.etsi.org/19602/PIDProvidersList/StatusDetn/EU",SchemeTypeCommunityRules:[{lang:"en",uriValue:"http://uri.etsi.org/19602/PIDProviders/schemerules/EU"}],SchemeTerritory:"EU",PolicyOrLegalNotice:[{LoTELegalNotice:"Local development LoTE; never use as production trust."}],PointersToOtherLoTE:[{LoTELocation:"https://localhost:9443/pid-providers.jwt",ServiceDigitalIdentities:[{X509Certificates:[{val:$loteCertificate}]}],LoTEQualifiers:[{LoTEType:"http://uri.etsi.org/19602/LoTEType/EUPIDProvidersList",SchemeOperatorName:[{lang:"en",value:"adorsys local development"}],SchemeTypeCommunityRules:[{lang:"en",uriValue:"http://uri.etsi.org/19602/PIDProviders/schemerules/EU"}],SchemeTerritory:"EU",MimeType:"application/jose"}]}],ListIssueDateTime:$issuedAt,NextUpdate:$nextUpdate},TrustedEntitiesList:[{TrustedEntityInformation:{TEName:[{lang:"en",value:"Adorsys Lab"}],TETradeName:[{lang:"en",value:$provider}],TEAddress:{TEPostalAddress:[{lang:"en",StreetAddress:"Local development",Country:"DE"}],TEElectronicAddress:[{lang:"en",uriValue:"mailto:local-pid@example.invalid"},{lang:"en",uriValue:"tel:+49000000000"}]},TEInformationURI:[{lang:"en",uriValue:"https://localhost:9443/provider-policy"},{lang:"en",uriValue:"https://localhost:9443/provider-info"},{lang:"en",uriValue:"http://uri.etsi.org/19602/ListOfTrustedEntities/PIDProvider/DE"}]},TrustedEntityServices:[{ServiceInformation:{ServiceTypeIdentifier:"http://uri.etsi.org/19602/SvcType/PID/Issuance",ServiceName:[{lang:"en",value:"Adorsys Lab PID issuance"}],ServiceDigitalIdentity:{X509Certificates:[{val:$certificate}]}}}]}]}}')"

encoded_header="$(printf '%s' "$header" | base64url)"
encoded_payload="$(printf '%s' "$payload" | base64url)"
signing_input="${encoded_header}.${encoded_payload}"
signature="$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$lote_key" | base64url)"
printf '%s.%s' "$signing_input" "$signature" > "$trust_list"

echo "Generated signed PID Provider LoTE: $trust_list"
echo "LoTE verification certificate (DER): $lote_cert_der"
echo "mDoc issuer certificate (DER): $issuer_cert_der"
