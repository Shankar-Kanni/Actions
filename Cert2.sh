#!/bin/bash

# === CONFIGURATION ===
CERT_URL="https://example.com/jwks.json"
NAMESPACE="your-namespace"
CONFIGMAP_NAME="your-configmap-name"
DEPLOYMENT_NAME="your-deployment-name"
TMP_DIR="/tmp/cert-rotate"
mkdir -p "$TMP_DIR"

# === STEP 1: Download JSON and extract certs ===
echo "🔽 Fetching JWKS..."
curl -s "$CERT_URL" | jq -r '.keys[].x5c[0]' > "$TMP_DIR/base64-certs.txt"

# === STEP 2: Wrap base64 certs into proper PEM files ===
count=0
for base64_cert in $(cat "$TMP_DIR/base64-certs.txt"); do
  PEM_FILE="$TMP_DIR/cert-$(printf "%02d" $count).pem"
  {
    echo "-----BEGIN CERTIFICATE-----"
    echo "$base64_cert"
    echo "-----END CERTIFICATE-----"
  } > "$PEM_FILE"
  count=$((count + 1))
done

# === STEP 3: Determine latest cert by NotBefore date ===
LATEST_CERT=""
LATEST_EPOCH=0

for cert in "$TMP_DIR"/cert-*.pem; do
  START_RAW=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2)
  [[ -z "$START_RAW" ]] && continue
  START_EPOCH=$(date -d "$START_RAW" +%s)
  echo "📅 Cert $cert starts at: $START_RAW"
  if (( START_EPOCH > LATEST_EPOCH )); then
    LATEST_EPOCH=$START_EPOCH
    LATEST_CERT="$cert"
  fi
done

if [[ -z "$LATEST_CERT" ]]; then
  echo "❌ No valid certificates found."
  exit 1
fi

echo "✅ Latest certificate is: $LATEST_CERT"
echo "⏱️  NotBefore: $(date -d @$LATEST_EPOCH)"

# === STEP 4: Compare with existing cert in ConfigMap ===
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cert\.pem}' > "$TMP_DIR/current-cert.pem" 2>/dev/null || touch "$TMP_DIR/current-cert.pem"

NEW_HASH=$(sha256sum "$LATEST_CERT" | awk '{print $1}')
OLD_HASH=$(sha256sum "$TMP_DIR/current-cert.pem" | awk '{print $1}')

if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
  echo "ℹ️ Certificate is unchanged. Exiting."
  exit 0
fi

# === STEP 5: Update ConfigMap and rollout restart ===
echo "🔁 Updating Kubernetes ConfigMap..."
kubectl create configmap "$CONFIGMAP_NAME" \
  --from-file=cert.pem="$LATEST_CERT" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🚀 Restarting deployment..."
kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"

echo "✅ Done! Cert updated and rollout triggered."
