#!/bin/bash

# === Config ===
CERT_URL="https://example.com/certs.json"
NAMESPACE="your-namespace"
CONFIGMAP_NAME="your-configmap-name"
DEPLOYMENT_NAME="your-deployment-name"
TMP_DIR="/tmp/cert-check"
mkdir -p "$TMP_DIR"

# === Step 1: Fetch and split certs ===
echo "Fetching certificates from $CERT_URL..."
curl -s "$CERT_URL" | jq -r '.[]' > "$TMP_DIR/all-certs.txt"

# Split PEMs into individual files
csplit -sz "$TMP_DIR/all-certs.txt" '/-----BEGIN CERTIFICATE-----/' '{*}' -f "$TMP_DIR/cert-" -b "%02d.pem"

# === Step 2: Find cert with latest NotAfter ===
LATEST_CERT=""
LATEST_TIMESTAMP=0

for cert in "$TMP_DIR"/cert-*.pem; do
  EXPIRY_RAW=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
  [[ -z "$EXPIRY_RAW" ]] && continue

  EXPIRY_EPOCH=$(date -d "$EXPIRY_RAW" +%s)
  if (( EXPIRY_EPOCH > LATEST_TIMESTAMP )); then
    LATEST_TIMESTAMP=$EXPIRY_EPOCH
    LATEST_CERT=$cert
  fi
done

if [[ -z "$LATEST_CERT" ]]; then
  echo "No valid certs found."
  exit 1
fi

echo "Using latest cert: $LATEST_CERT"

# === Step 3: Get current cert from ConfigMap ===
REMOTE_CERT="$LATEST_CERT"
LOCAL_CERT="$TMP_DIR/current-cert.pem"
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cert\.pem}' > "$LOCAL_CERT" 2>/dev/null || touch "$LOCAL_CERT"

# === Step 4: Compare ===
NEW_HASH=$(sha256sum "$REMOTE_CERT" | awk '{print $1}')
OLD_HASH=$(sha256sum "$LOCAL_CERT" | awk '{print $1}')

if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
  echo "Certificate has not changed. No update needed."
  exit 0
fi

echo "Certificate has changed. Updating ConfigMap..."

# === Step 5: Update ConfigMap ===
kubectl create configmap "$CONFIGMAP_NAME" \
  --from-file=cert.pem="$REMOTE_CERT" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# === Step 6: Rollout restart ===
kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
echo "Done."
