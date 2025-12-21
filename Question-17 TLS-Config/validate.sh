#!/bin/bash
set -e

# --- Resolve kubectl safely ---
KUBECTL=$(command -v kubectl || true)
if [[ -z "$KUBECTL" ]]; then
  echo "FAIL: kubectl not found"
  exit 1
fi

NS="nginx-static"
SVC="nginx-static"
CM_NAME="nginx-config"
HOST="ckaquestion.k8s.local"

echo "=== TLSv1.3 Validation ==="

# --------------------------------------------------
# 1. Validate Service and determine Service IP
# --------------------------------------------------
$KUBECTL get svc "$SVC" -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: Service $SVC not found in $NS"; exit 1; }

SVC_IP=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.clusterIP}')

if [[ -z "$SVC_IP" ]]; then
  echo "FAIL: Could not determine Service IP"
  exit 1
fi

echo "PASS: Service IP detected: $SVC_IP"

# --------------------------------------------------
# 2. Validate /etc/hosts entry
# --------------------------------------------------
HOST_ENTRY=$(grep -E "^[^#].*$HOST" /etc/hosts || true)

if [[ -z "$HOST_ENTRY" ]]; then
  echo "FAIL: /etc/hosts does not contain $HOST"
  exit 1
fi

echo "$HOST_ENTRY" | grep -q "$SVC_IP" \
  && echo "PASS: /etc/hosts maps $HOST to $SVC_IP" \
  || { echo "FAIL: /etc/hosts does not map $HOST to Service IP"; exit 1; }

# --------------------------------------------------
# 3. Validate ConfigMap TLS configuration
# --------------------------------------------------
$KUBECTL get configmap "$CM_NAME" -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: ConfigMap $CM_NAME not found in $NS"; exit 1; }

CM_CONTENT=$($KUBECTL get configmap "$CM_NAME" -n "$NS" -o yaml)

# Must explicitly allow TLSv1.3
echo "$CM_CONTENT" | grep -q "ssl_protocols.*TLSv1.3" \
  && echo "PASS: TLSv1.3 explicitly enabled in ConfigMap" \
  || { echo "FAIL: TLSv1.3 not correctly configured in ConfigMap"; exit 1; }

# Must NOT allow TLSv1.2
if echo "$CM_CONTENT" | grep -q "TLSv1.2"; then
  echo "FAIL: TLSv1.2 is still enabled in ConfigMap"
  exit 1
fi

echo "PASS: TLSv1.2 is disabled"

# --------------------------------------------------
# 4. Runtime TLS verification
# --------------------------------------------------
echo "Testing TLSv1.2 (should FAIL)..."
if curl -sk --tls-max 1.2 https://$HOST >/dev/null; then
  echo "FAIL: TLSv1.2 connection succeeded (should fail)"
  exit 1
fi
echo "PASS: TLSv1.2 correctly rejected"

echo "Testing TLSv1.3 (should SUCCEED)..."
curl -sk --tlsv1.3 https://$HOST >/dev/null \
  && echo "PASS: TLSv1.3 connection successful" \
  || { echo "FAIL: TLSv1.3 connection failed"; exit 1; }

echo "=== VALIDATION COMPLETE ==="
echo "TLSv1.3-only configuration is CORRECT"

