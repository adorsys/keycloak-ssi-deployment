#!/bin/bash

# Variables
source load_env.sh

# Ensure JAVA_HOME is set for building the CLI
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

if [ -f "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" ]; then
  echo "Config cli jar file exists..."
else 
  # Check if the CLI project folder already exists, if so remove and clone again...
  if [ -d "$KC_CLI_PROJECT_DIR" ]; then
    echo "Directory $KC_CLI_PROJECT_DIR exists. Removing it..."
    rm -rf "$KC_CLI_PROJECT_DIR" || { echo "Failed to remove directory $KC_CLI_PROJECT_DIR"; exit 1; }
  else
    echo "Directory does not exist"
  fi

  # Only clone the main branch of the Git repository if not existent
  echo "Cloning repository from ${REPO_URL}..."
  cd $TARGET_DIR && git clone "$REPO_URL" || { echo "Failed to clone repository"; exit 1; }

  # Navigate to the cloned repository
  cd "$KC_CLI_PROJECT_DIR" || { echo "Failed to navigate to $KC_CLI_PROJECT_DIR"; exit 1; }

  # Fetch all tags
  echo "Fetching tags from the repository..."
  git fetch --tags || { echo "Failed to fetch tags"; exit 1; }

  if [ -n "$TAG" ]; then
    # Switch to the desired release tag
    echo "Checking out tag $TAG..."
    git checkout tags/$TAG -b $TAG || { echo "Failed to checkout tag $TAG"; exit 1; }
  else
    echo "No tag specified. Using the default branch."
  fi

  # Build CLI tool
  ./mvnw clean install -DskipTests || { echo "Failed to build the CLI tool"; exit 1; }

  # Check if JAR file is created in the target directory
  if ls target/*.jar 1> /dev/null 2>&1; then
    echo "Build successful! JAR file created."
  else
    echo "Build failed! No JAR file found."
    exit 1
  fi
fi

# Export environment variables used by the realm JSON substitution
# these are referenced as env:KEYSTORE_PATH and env:KEYSTORE_PASSWORD in the JSON
export KEYSTORE_PATH="$KC_KEYSTORE_PATH"
export KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD"
export CLIENT_SECRET="$CLIENT_SECRET"
export ISSUER_BACKEND_URL="$ISSUER_BACKEND_URL"
export ISSUER_FRONTEND_URL="$ISSUER_FRONTEND_URL"
export ISSUER_DID="$ISSUER_DID"
export TEST_CLIENT_URL="$TEST_CLIENT_URL"

# If the realm already exists, remove it so the import can recreate it cleanly.
# This prevents HTTP 400 errors from the config CLI when updating components.
echo "Deleting existing realm $KEYCLOAK_REALM (if present)"

# Configure truststore for kcadm.sh
$KC_INSTALL_DIR/bin/kcadm.sh config truststore --trustpass "$KC_TRUST_STORE_PASS" "$KC_TRUST_STORE"

$KC_INSTALL_DIR/bin/kcadm.sh config credentials --server "$KEYCLOAK_URL" --realm master \
    --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD

# Use get realms and grep for the exact realm name
if $KC_INSTALL_DIR/bin/kcadm.sh get realms --fields realm | grep -q "\"realm\" : \"$KEYCLOAK_REALM\""; then
    echo "Realm $KEYCLOAK_REALM detected. Initiating complete deletion..."
    $KC_INSTALL_DIR/bin/kcadm.sh delete realms/$KEYCLOAK_REALM
    if [ $? -eq 0 ]; then
        echo "Realm $KEYCLOAK_REALM deleted successfully. Waiting for cleanup..."
        sleep 5
    else
        echo "Failed to delete realm $KEYCLOAK_REALM. Check if it was already deleted or if there are other issues."
    fi
else
    echo "Realm $KEYCLOAK_REALM not found. Proceeding with import."
fi


# Run the JAR file with the specified parameters
# When running locally, let the option keycloak.ssl-verify be false otherwise let it be true.
echo "Running the JAR file..."
java -DCLIENT_SECRET="$CLIENT_SECRET" \
     -DKEYCLOAK_EXTERNAL_ADDR="$KEYCLOAK_EXTERNAL_ADDR" \
     -DKEYCLOAK_KEYSTORE_PASSWORD="$KEYCLOAK_KEYSTORE_PASSWORD" \
     -DKC_KEYSTORE_PATH="$KC_KEYSTORE_PATH" \
     -DKEYCLOAK_REALM="$KEYCLOAK_REALM" \
     -DISSUER_BACKEND_URL="$ISSUER_BACKEND_URL" \
     -DISSUER_FRONTEND_URL="$ISSUER_FRONTEND_URL" \
     -DISSUER_DID="$ISSUER_DID" \
     -DSAML_ENTITYID="$ISSUER_DID" \
     -DTEST_CLIENT_URL="$TEST_CLIENT_URL" \
     -jar "$KC_CLI_PROJECT_DIR/target/$KC_CLI_JAR_FILE" \
     -Dimport-realm=true \
     --import.var-substitution.enabled=true \
     --keycloak.url="$KEYCLOAK_URL" \
     --keycloak.user="$KC_BOOTSTRAP_ADMIN_USERNAME" \
     --keycloak.password="$KC_BOOTSTRAP_ADMIN_PASSWORD" \
     --keycloak.ssl-verify=false \
     --logging.level.root=info \
     --import.files.locations="$KC_REALM_FILE" || { echo "Failed to run the JAR file"; exit 1; }

# After import, ensure OID4VCI realm attributes for signed metadata and encryption are set
echo "Setting OID4VCI realm attributes on $KEYCLOAK_REALM ..."

# Get current realm to merge attributes properly
echo "Fetching current realm before update..."
REALM_JSON=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" 2>&1)
echo "Current attributes (before update):"
if command -v jq >/dev/null 2>&1 && echo "$REALM_JSON" | jq -e '.attributes' >/dev/null 2>&1; then
  echo "$REALM_JSON" | jq '.attributes'
else
  echo "$REALM_JSON" | head -20
fi
echo ""

# Use jq to merge attributes properly (similar to configure_attestation_trusted_keys.sh)
if command -v jq >/dev/null 2>&1; then
  # Get existing attributes and merge with new ones
  if [ -n "$REALM_JSON" ] && echo "$REALM_JSON" | jq -e '.attributes' >/dev/null 2>&1; then
    # Merge with existing attributes - ensure attributes object exists
    REALM_UPDATE_JSON=$(echo "$REALM_JSON" | jq '.attributes = ((.attributes // {}) + {
      "oid4vci.encryption.required": "true",
      "oid4vci.signed_metadata.enabled": "true",
      "oid4vci.signed_metadata.alg": "RS256",
      "oid4vci.signed_metadata.lifespan": "3600",
      "oid4vci.request.zip.algorithms": "DEF"
    })')
  else
    # If we can't parse the realm JSON, try to get just attributes and merge
    REALM_ATTRS_JSON=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" --fields attributes 2>&1)
    if echo "$REALM_ATTRS_JSON" | jq -e '.attributes' >/dev/null 2>&1; then
      REALM_UPDATE_JSON=$(echo "$REALM_ATTRS_JSON" | jq '.attributes = ((.attributes // {}) + {
        "oid4vci.encryption.required": "true",
        "oid4vci.signed_metadata.enabled": "true",
        "oid4vci.signed_metadata.alg": "RS256",
        "oid4vci.signed_metadata.lifespan": "3600",
        "oid4vci.request.zip.algorithms": "DEF"
      })')
    else
      # Create new attributes object if it doesn't exist
      REALM_UPDATE_JSON=$(jq -n '{
        "attributes": {
          "oid4vci.encryption.required": "true",
          "oid4vci.signed_metadata.enabled": "true",
          "oid4vci.signed_metadata.alg": "RS256",
          "oid4vci.signed_metadata.lifespan": "3600",
          "oid4vci.request.zip.algorithms": "DEF"
        }
      }')
    fi
  fi
  
  echo "Realm update payload:"
  echo "$REALM_UPDATE_JSON" | jq .
  
  # Use kcadm.sh to update the realm by piping JSON via stdin (same approach as configure_attestation_trusted_keys.sh)
  echo "Sending update to Keycloak..."
  UPDATE_OUTPUT=$(echo "$REALM_UPDATE_JSON" | $KC_INSTALL_DIR/bin/kcadm.sh update "realms/$KEYCLOAK_REALM" -f - 2>&1)
  UPDATE_EXIT_CODE=$?
  
  echo "Update command exit code: $UPDATE_EXIT_CODE"
  echo "Update command output:"
  echo "$UPDATE_OUTPUT"
  echo ""
  
  if [ $UPDATE_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Failed to set OID4VCI realm attributes (exit code: $UPDATE_EXIT_CODE)"
    exit 1
  fi
  
  # Check if update actually succeeded (kcadm.sh might return 0 even if update failed)
  if echo "$UPDATE_OUTPUT" | grep -qi "error\|failed\|not found"; then
    echo "WARNING: kcadm.sh may have encountered an error in output"
  else
    echo "Update command completed successfully (no errors in output)"
  fi
  
  # Small delay to ensure Keycloak has processed the update
  sleep 2
  
  # Immediately verify after update
  echo "Immediate verification after update..."
  IMMEDIATE_VERIFY=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" --fields attributes 2>&1)
  if command -v jq >/dev/null 2>&1 && echo "$IMMEDIATE_VERIFY" | jq -e '.attributes' >/dev/null 2>&1; then
    echo "Attributes immediately after update:"
    echo "$IMMEDIATE_VERIFY" | jq '.attributes'
  else
    echo "Raw output: $IMMEDIATE_VERIFY"
  fi
  echo ""
else
  # Fallback: Use JSON format without jq
  REALM_ATTRIBUTES_JSON=$(cat <<EOF
{
  "attributes": {
    "oid4vci.encryption.required": "true",
    "oid4vci.signed_metadata.enabled": "true",
    "oid4vci.signed_metadata.alg": "RS256",
    "oid4vci.signed_metadata.lifespan": "3600",
    "oid4vci.request.zip.algorithms": "DEF"
  }
}
EOF
)
  UPDATE_OUTPUT=$(echo "$REALM_ATTRIBUTES_JSON" | $KC_INSTALL_DIR/bin/kcadm.sh update "realms/$KEYCLOAK_REALM" -f - 2>&1)
  UPDATE_EXIT_CODE=$?
  
  if [ $UPDATE_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Failed to set OID4VCI realm attributes"
    echo "kcadm.sh output: $UPDATE_OUTPUT"
    exit 1
  fi
  
  # Check if update actually succeeded
  if echo "$UPDATE_OUTPUT" | grep -qi "error\|failed\|not found"; then
    echo "WARNING: kcadm.sh may have encountered an error:"
    echo "$UPDATE_OUTPUT"
  fi
fi

echo "✅ OID4VCI realm attributes set successfully"

# Verify the attributes by checking the metadata endpoint (most reliable method)
echo ""
echo "Verifying OID4VCI attributes via metadata endpoint..."
echo "Waiting a bit for Keycloak to process the update..."
sleep 3

METADATA_URL="$KEYCLOAK_URL/.well-known/openid-credential-issuer/realms/$KEYCLOAK_REALM"
echo "Checking: $METADATA_URL"

# Check if metadata endpoint returns signed JWT (indicates signed metadata is enabled)
METADATA_RESPONSE=$(curl -s -k -H "Accept: application/jwt" "$METADATA_URL" 2>&1)
if echo "$METADATA_RESPONSE" | grep -q "^eyJ"; then
  echo "  ✓ Metadata endpoint returns signed JWT"
  echo "  ✓ Signed metadata is enabled and functioning correctly"
  
  # Decode JWT payload (base64url decode the middle part) to check encryption_required
  JWT_PAYLOAD=$(echo "$METADATA_RESPONSE" | cut -d. -f2)
  # Add padding if needed for base64 decoding
  PADDING=$((4 - ${#JWT_PAYLOAD} % 4))
  if [ $PADDING -ne 4 ]; then
    JWT_PAYLOAD="${JWT_PAYLOAD}$(printf '%*s' $PADDING '' | tr ' ' '=')"
  fi
  DECODED_PAYLOAD=$(echo "$JWT_PAYLOAD" | base64 -d 2>/dev/null || echo "")
  if echo "$DECODED_PAYLOAD" | grep -q '"encryption_required":true'; then
    echo "  ✓ Encryption is configured (encryption_required: true in signed metadata)"
  elif echo "$DECODED_PAYLOAD" | grep -q '"encryption_required":false'; then
    echo "  ✗ WARNING: encryption_required is false in metadata"
    echo "    The attribute may not have been set correctly. Check realm attributes."
  fi
elif echo "$METADATA_RESPONSE" | grep -q '"encryption_required":true'; then
  # Check JSON response for encryption_required
  echo "  ✓ Metadata endpoint shows encryption_required: true (encryption is configured)"
  echo "  ⚠ Signed metadata may not be enabled (returning JSON instead of JWT)"
elif echo "$METADATA_RESPONSE" | grep -q '"encryption_required":false'; then
  echo "  ✗ WARNING: encryption_required is false in metadata"
  echo "    The attribute may not have been set correctly. Check realm attributes."
else
  echo "  ⚠ Could not verify attributes via metadata endpoint"
  echo "  Response preview: $(echo "$METADATA_RESPONSE" | head -c 200)"
fi

# Ensure the realm exposes ECDH-ES for credential_response_encryption by provisioning an ECDH (P-256) ENC key provider.
# This is needed for OID4VCI conformance tests that use `credential_response_encryption.jwk.alg = ECDH-ES`.
echo ""
echo "Ensuring ECDH-ES encryption key provider exists (providerId=ecdh-generated) ..."

if command -v jq >/dev/null 2>&1; then
  REALM_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" 2>/dev/null | jq -r '.id // empty')
  if [ -z "$REALM_ID" ] || [ "$REALM_ID" = "null" ]; then
    echo "WARNING: Could not resolve realm id for $KEYCLOAK_REALM; skipping ECDH key provider provisioning."
  else
    EXISTING_ECDH_COMPONENT_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get components -r "$KEYCLOAK_REALM" 2>/dev/null | jq -r '.[] | select(.providerId=="ecdh-generated") | .id' | head -n 1)

    if [ -n "$EXISTING_ECDH_COMPONENT_ID" ] && [ "$EXISTING_ECDH_COMPONENT_ID" != "null" ]; then
      echo "✅ ECDH key provider already present (id=$EXISTING_ECDH_COMPONENT_ID)"
    else
      echo "Creating ECDH key provider component (ECDH-ES, P-256, use=enc) ..."
      ECDH_COMPONENT_JSON=$(jq -n \
        --arg name "ecdh-enc-key" \
        --arg parentId "$REALM_ID" \
        '{
          "name": $name,
          "providerId": "ecdh-generated",
          "providerType": "org.keycloak.keys.KeyProvider",
          "parentId": $parentId,
          "config": {
            "priority": ["102"],
            "enabled": ["true"],
            "active": ["true"],
            "ecGenerateCertificate": ["true"],
            "ecdhAlgorithm": ["ECDH-ES"],
            "ecdhEllipticCurveKey": ["P-256"]
          }
        }')

      CREATE_OUT=$($KC_INSTALL_DIR/bin/kcadm.sh create components -r "$KEYCLOAK_REALM" -f - <<<"$ECDH_COMPONENT_JSON" 2>&1)
      CREATE_EXIT=$?
      if [ $CREATE_EXIT -ne 0 ]; then
        echo "WARNING: Failed to create ECDH key provider (exit=$CREATE_EXIT). Output:"
        echo "$CREATE_OUT"
      else
        echo "✅ Created ECDH key provider (ecdh-generated)."
      fi
    fi

    # Verify metadata advertises ECDH-ES (conformance suite uses ECDH-ES for credential_response_encryption)
    echo "Re-checking metadata for ECDH-ES support..."
    sleep 2
    METADATA_JSON=$(curl -s -k -H "Accept: application/json" "$METADATA_URL" 2>/dev/null || echo "")
    if echo "$METADATA_JSON" | grep -q '"ECDH-ES"'; then
      echo "  ✓ Metadata advertises ECDH-ES"
    else
      echo "  ⚠ WARNING: Metadata does not advertise ECDH-ES yet."
      echo "    Response preview: $(echo "$METADATA_JSON" | head -c 200)"
    fi
  fi
else
  echo "WARNING: jq not available; skipping ECDH key provider provisioning."
fi

# Optionally configure HAIP VC signing key from an external keystore (non self-signed leaf certificate)
#
# Requirements:
# - Environment variable HAIP_VC_SIGNER_KEYSTORE_PATH points to a PKCS#12 keystore on the Keycloak host
# - Environment variable HAIP_VC_SIGNER_KEYSTORE_PASSWORD contains the keystore password
# - Optional: HAIP_VC_SIGNER_KEY_ALIAS (defaults to 'haip-vc-signer')
#
# The keystore should contain:
# - Private key for the VC signing key
# - Leaf certificate signed by a CA (i.e. NOT self-signed)
echo ""
echo "Checking if HAIP VC signing keystore configuration is provided ..."

if [ -n "$HAIP_VC_SIGNER_KEYSTORE_PATH" ] && [ -f "$HAIP_VC_SIGNER_KEYSTORE_PATH" ] && [ -n "$HAIP_VC_SIGNER_KEYSTORE_PASSWORD" ]; then
  echo "HAIP VC signing keystore detected at: $HAIP_VC_SIGNER_KEYSTORE_PATH"

  if command -v jq >/dev/null 2>&1; then
    REALM_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" 2>/dev/null | jq -r '.id // empty')
    if [ -z "$REALM_ID" ] || [ "$REALM_ID" = "null" ]; then
      echo "WARNING: Could not resolve realm id for $KEYCLOAK_REALM; skipping HAIP VC signer provisioning."
    else
      # Use provided alias or a sensible default
      HAIP_ALIAS="${HAIP_VC_SIGNER_KEY_ALIAS:-haip-vc-signer}"

      # Check if a matching java-keystore provider already exists
      EXISTING_HAIP_SIG_ID=$($KC_INSTALL_DIR/bin/kcadm.sh get components -r "$KEYCLOAK_REALM" 2>/dev/null | \
        jq -r --arg path "$HAIP_VC_SIGNER_KEYSTORE_PATH" --arg alias "$HAIP_ALIAS" '
          .[] | select(.providerId=="java-keystore")
              | select(.config.keystore[0]==$path and .config.keyAlias[0]==$alias)
              | .id' | head -n 1)

      if [ -n "$EXISTING_HAIP_SIG_ID" ] && [ "$EXISTING_HAIP_SIG_ID" != "null" ]; then
        echo "✅ HAIP VC signer keystore provider already present (id=$EXISTING_HAIP_SIG_ID)"
      else
        echo "Creating HAIP VC signer keystore provider (algorithm=ES256, keyUse=sig) ..."

        HAIP_SIG_COMPONENT_JSON=$(jq -n \
          --arg name "haip-vc-signer-keystore" \
          --arg parentId "$REALM_ID" \
          --arg ksPath "$HAIP_VC_SIGNER_KEYSTORE_PATH" \
          --arg ksPass "$HAIP_VC_SIGNER_KEYSTORE_PASSWORD" \
          --arg alias "$HAIP_ALIAS" \
          '{
            "name": $name,
            "providerId": "java-keystore",
            "providerType": "org.keycloak.keys.KeyProvider",
            "parentId": $parentId,
            "config": {
              "keystore": [$ksPath],
              "keystorePassword": [$ksPass],
              "keyAlias": [$alias],
              "keyPassword": [$ksPass],
              "priority": ["200"],
              "enabled": ["true"],
              "active": ["true"],
              "algorithm": ["ES256"],
              "keyUse": ["sig"]
            }
          }')

        HAIP_CREATE_OUT=$($KC_INSTALL_DIR/bin/kcadm.sh create components -r "$KEYCLOAK_REALM" -f - <<<"$HAIP_SIG_COMPONENT_JSON" 2>&1)
        HAIP_CREATE_EXIT=$?
        if [ $HAIP_CREATE_EXIT -ne 0 ]; then
          echo "WARNING: Failed to create HAIP VC signer keystore provider (exit=$HAIP_CREATE_EXIT). Output:"
          echo "$HAIP_CREATE_OUT"
        else
          echo "✅ Created HAIP VC signer keystore provider (java-keystore, alias=$HAIP_ALIAS)."
        fi
      fi

      # Ensure HAIP VC signer is the active ES256 signing key by disabling older ECDSA-generated SIG keys
      echo "Ensuring HAIP VC signer is the active ES256 signing key (disabling legacy ECDSA signing keys) ..."
      ECDSA_SIG_IDS=$($KC_INSTALL_DIR/bin/kcadm.sh get components -r "$KEYCLOAK_REALM" 2>/dev/null | \
        jq -r '.[] | select(.providerId=="ecdsa-generated") | .id')

      if [ -z "$ECDSA_SIG_IDS" ]; then
        echo "  No ecdsa-generated key providers found; nothing to disable."
      else
        for E_ID in $ECDSA_SIG_IDS; do
          echo "  Disabling legacy ECDSA signing provider id=$E_ID"
          $KC_INSTALL_DIR/bin/kcadm.sh update "components/$E_ID" -r "$KEYCLOAK_REALM" \
            -s 'config.enabled=false' \
            -s 'config.active=false' >/dev/null 2>&1 || \
            echo "    WARNING: Failed to update ECDSA provider id=$E_ID"
        done
      fi
    fi
  else
    echo "WARNING: jq not available; skipping HAIP VC signer keystore provisioning."
  fi
else
  echo "No HAIP VC signing keystore configured (set HAIP_VC_SIGNER_KEYSTORE_PATH and HAIP_VC_SIGNER_KEYSTORE_PASSWORD to enable)."
fi

# Optionally configure attestation trusted keys if file is provided
if [ -n "$ATTESTATION_TRUSTED_KEYS_FILE" ] && [ -f "$ATTESTATION_TRUSTED_KEYS_FILE" ]; then
  echo ""
  echo "Configuring attestation trusted keys from: $ATTESTATION_TRUSTED_KEYS_FILE"
  
  if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq is required for attestation keys configuration. Skipping..."
  else
    # Extract public keys (remove 'd' parameter if present) and convert to array
    TRUSTED_KEYS_JSON=$(jq -c '.keys[] | del(.d) | select(.kid != null)' "$ATTESTATION_TRUSTED_KEYS_FILE" | jq -s '.')
    
    if [ -z "$TRUSTED_KEYS_JSON" ] || [ "$TRUSTED_KEYS_JSON" = "[]" ]; then
      echo "WARNING: No valid keys found in attestation trusted keys file. Skipping..."
    else
      echo "Trusted keys to configure:"
      echo "$TRUSTED_KEYS_JSON" | jq .
      
      # Convert the JSON array to a compact string for the realm attribute
      TRUSTED_KEYS_STRING=$(echo "$TRUSTED_KEYS_JSON" | jq -c .)
      
      # Get current realm attributes to merge properly (preserve OID4VCI attributes)
      echo "Fetching current realm attributes to merge..."
      CURRENT_ATTRS_JSON=$($KC_INSTALL_DIR/bin/kcadm.sh get "realms/$KEYCLOAK_REALM" --fields attributes 2>&1)
      
      # Extract existing OID4VCI values or use defaults
      EXISTING_ENCRYPTION=$(echo "$CURRENT_ATTRS_JSON" | jq -r '.attributes."oid4vci.encryption.required" // "true"')
      EXISTING_SIGNED_META=$(echo "$CURRENT_ATTRS_JSON" | jq -r '.attributes."oid4vci.signed_metadata.enabled" // "true"')
      EXISTING_ALG=$(echo "$CURRENT_ATTRS_JSON" | jq -r '.attributes."oid4vci.signed_metadata.alg" // "RS256"')
      EXISTING_LIFESPAN=$(echo "$CURRENT_ATTRS_JSON" | jq -r '.attributes."oid4vci.signed_metadata.lifespan" // "3600"')
      EXISTING_ZIP=$(echo "$CURRENT_ATTRS_JSON" | jq -r '.attributes."oid4vci.request.zip.algorithms" // "DEF"')
      
      # Merge with existing attributes - explicitly preserve OID4VCI attributes
      if [ -n "$CURRENT_ATTRS_JSON" ] && echo "$CURRENT_ATTRS_JSON" | jq -e '.attributes' >/dev/null 2>&1; then
        REALM_UPDATE_JSON=$(echo "$CURRENT_ATTRS_JSON" | jq \
          --arg trusted_keys_str "$TRUSTED_KEYS_STRING" \
          --arg encryption_req "$EXISTING_ENCRYPTION" \
          --arg signed_meta "$EXISTING_SIGNED_META" \
          --arg alg "$EXISTING_ALG" \
          --arg lifespan "$EXISTING_LIFESPAN" \
          --arg zip "$EXISTING_ZIP" \
          '.attributes = ((.attributes // {}) + {
            "oid4vc.attestation.trusted_keys": $trusted_keys_str,
            "oid4vci.encryption.required": $encryption_req,
            "oid4vci.signed_metadata.enabled": $signed_meta,
            "oid4vci.signed_metadata.alg": $alg,
            "oid4vci.signed_metadata.lifespan": $lifespan,
            "oid4vci.request.zip.algorithms": $zip
          })')
        echo "Merging attestation keys with existing realm attributes (preserving OID4VCI attributes)"
      else
        # Create new attributes object - include OID4VCI attributes by default
        REALM_UPDATE_JSON=$(jq -n \
          --arg trusted_keys_str "$TRUSTED_KEYS_STRING" \
          '{
            "attributes": {
              "oid4vc.attestation.trusted_keys": $trusted_keys_str,
              "oid4vci.encryption.required": "true",
              "oid4vci.signed_metadata.enabled": "true",
              "oid4vci.signed_metadata.alg": "RS256",
              "oid4vci.signed_metadata.lifespan": "3600",
              "oid4vci.request.zip.algorithms": "DEF"
            }
          }')
        echo "Creating new realm attributes (including OID4VCI defaults)"
      fi
      
      echo "Realm update payload (attributes only):"
      echo "$REALM_UPDATE_JSON" | jq '.attributes'
      
      # Update the realm
      UPDATE_OUTPUT=$(echo "$REALM_UPDATE_JSON" | $KC_INSTALL_DIR/bin/kcadm.sh update "realms/$KEYCLOAK_REALM" -f - 2>&1)
      UPDATE_EXIT_CODE=$?
      
      if [ $UPDATE_EXIT_CODE -ne 0 ]; then
        echo "ERROR: Failed to configure attestation trusted keys"
        echo "kcadm.sh output: $UPDATE_OUTPUT"
      else
        echo "✅ Successfully configured attestation trusted keys"
        echo "Number of keys configured: $(echo "$TRUSTED_KEYS_JSON" | jq 'length')"
      fi
    fi
  fi
elif [ -n "$ATTESTATION_TRUSTED_KEYS_FILE" ]; then
  echo ""
  echo "WARNING: Attestation trusted keys file specified but not found: $ATTESTATION_TRUSTED_KEYS_FILE"
  echo "Skipping attestation keys configuration..."
fi

# After import, update sd-jwt authenticator
# echo "Ensuring sd-jwt authenticator VCT is configured"
# . ./update_sdjwt_vct.sh

echo ""
echo "Script completed successfully."