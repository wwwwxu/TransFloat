#!/bin/bash
# One-time setup: creates a stable self-signed code signing certificate.
# After running this, Accessibility permission will persist across builds.

CERT_NAME="TransFloat Developer"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "✅ Certificate '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

echo "🔐 Creating self-signed code signing certificate..."
TMP=$(mktemp -d)

# Generate config with code signing extension
cat > "$TMP/cert.cnf" << EOF
[req]
distinguished_name = req_dn
x509_extensions    = v3_cs
prompt             = no

[req_dn]
CN = $CERT_NAME

[v3_cs]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:FALSE
subjectKeyIdentifier = hash
EOF

# Generate key + self-signed cert
openssl genrsa -out "$TMP/key.pem" 2048 2>/dev/null
openssl req -new -x509 -days 3650 \
    -key "$TMP/key.pem" \
    -out "$TMP/cert.pem" \
    -config "$TMP/cert.cnf" 2>/dev/null

# Bundle into PKCS#12 (empty password)
openssl pkcs12 -export \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" \
    -passout pass: 2>/dev/null

# Import into login keychain
echo "📥 Importing certificate (you may see a password prompt for your login keychain)..."
security import "$TMP/cert.p12" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "" -T /usr/bin/codesign -T /usr/bin/security

# Trust the cert for code signing
echo "🔑 Setting trust (you may be prompted for your macOS password)..."
security add-trusted-cert \
    -d -r trustRoot \
    -p codeSign \
    -k ~/Library/Keychains/login.keychain-db \
    "$TMP/cert.pem"

rm -rf "$TMP"

# Verify
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo ""
    echo "✅ Certificate '$CERT_NAME' created successfully!"
    echo "   Now run: bash build.sh"
    echo "   Accessibility permission will persist across all future builds."
else
    echo ""
    echo "❌ Certificate creation failed."
    echo "   Manual fallback: open Keychain Access → Certificate Assistant → Create a Certificate"
    echo "   Name: $CERT_NAME  |  Type: Self Signed Root  |  Usage: Code Signing"
fi
