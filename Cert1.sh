#!/bin/bash

CERT_URL="https://example.com/certs.json"
NAMESPACE="your-namespace"
CONFIGMAP_NAME="your-configmap-name"
DEPLOYMENT_NAME="your-deployment-name"
TMP_DIR="/tmp/cert-rotate"
mkdir -p "$TMP_DIR"

# Step 1: Download the JSON
echo "Downloading certificate JSON..."
curl -s "$CERT_URL" > "$TMP_DIR/certs.json"

# Step 2: Extract all cert values into separate files
jq -r 'to_entries[] | "\(.key)\n\(.value)"' "$TMP_DIR/certs.json" | while read -r key; do
  read -r value
  PEM_FILE="$TMP_DIR/$key.pem"
  {
    echo "-----BEGIN CERTIFICATE-----"
    echo "$value"
    echo "-----END CERTIFICATE-----"
  } > "$PEM_FILE"
done

# Step 3: Find cert with latest Not Before date
LATEST_CERT=""
LATEST_EPOCH=0

for cert in "$TMP_DIR"/*.pem; do
  START_RAW=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2)
  [[ -z "$START_RAW" ]] && continue
  START_EPOCH=$(date -d "$START_RAW" +%s)
  if (( START_EPOCH > LATEST_EPOCH )); then
    LATEST_EPOCH=$START_EPOCH
    LATEST_CERT="$cert"
  fi
done

if [[ -z "$LATEST_CERT" ]]; then
  echo "❌ No valid certs found."
  exit 1
fi

echo "✅ Latest cert starts on: $(date -d @$LATEST_EPOCH)"
echo "📄 Using cert file: $LATEST_CERT"

# Step 4: Compare with current ConfigMap cert
REMOTE_CERT="$LATEST_CERT"
LOCAL_CERT="$TMP_DIR/current-cert.pem"
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cert\.pem}' > "$LOCAL_CERT" 2>/dev/null || touch "$LOCAL_CERT"

NEW_HASH=$(sha256sum "$REMOTE_CERT" | awk '{print $1}')
OLD_HASH=$(sha256sum "$LOCAL_CERT" | awk '{print $1}')

if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
  echo "ℹ️ Certificate hasn't changed."
  exit 0
fi

# Step 5: Update ConfigMap and restart deployment
echo "🔄 Certificate changed — updating ConfigMap..."

kubectl create configmap "$CONFIGMAP_NAME" \
  --from-file=cert.pem="$REMOTE_CERT" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"

echo "✅ ConfigMap updated and deployment restarted."
