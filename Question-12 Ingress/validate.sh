#!/bin/bash
set -e

# --- Resolve kubectl safely ---
KUBECTL=$(command -v kubectl || true)

if [[ -z "$KUBECTL" ]]; then
  echo "FAIL: kubectl not found in PATH"
  exit 1
fi

NS="echo-sound"
SVC="echo-service"
ING="echo"

echo "=== Ingress Validation: echo ==="

# 1. Namespace check
$KUBECTL get ns "$NS" >/dev/null 2>&1 \
  && echo "PASS: Namespace $NS exists" \
  || { echo "FAIL: Namespace $NS not found"; exit 1; }

# 2. Service validation
$KUBECTL get svc "$SVC" -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: Service $SVC not found"; exit 1; }

TYPE=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.type}')
PORT=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].port}')
NODEPORT=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].nodePort}')

[[ "$TYPE" == "NodePort" ]] \
  && echo "PASS: Service type is NodePort" \
  || { echo "FAIL: Service type is not NodePort"; exit 1; }

[[ "$PORT" == "8080" ]] \
  && echo "PASS: Service port is 8080" \
  || { echo "FAIL: Service port is not 8080"; exit 1; }

[[ -n "$NODEPORT" ]] \
  && echo "PASS: NodePort assigned: $NODEPORT" \
  || { echo "FAIL: NodePort not assigned"; exit 1; }

# 3. Ingress validation
$KUBECTL get ingress "$ING" -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: Ingress $ING not found"; exit 1; }

HOST=$($KUBECTL get ingress "$ING" -n "$NS" -o jsonpath='{.spec.rules[0].host}')
PATH_VAL=$($KUBECTL get ingress "$ING" -n "$NS" -o jsonpath='{.spec.rules[0].http.paths[0].path}')
BACKEND_SVC=$($KUBECTL get ingress "$ING" -n "$NS" \
  -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
BACKEND_PORT=$($KUBECTL get ingress "$ING" -n "$NS" \
  -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')

[[ "$HOST" == "example.org" ]] \
  && echo "PASS: Ingress host is example.org" \
  || { echo "FAIL: Ingress host mismatch"; exit 1; }

[[ "$PATH_VAL" == "/echo" ]] \
  && echo "PASS: Ingress path is /echo" \
  || { echo "FAIL: Ingress path mismatch"; exit 1; }

[[ "$BACKEND_SVC" == "$SVC" ]] \
  && echo "PASS: Ingress routes to echo-service" \
  || { echo "FAIL: Ingress backend service mismatch"; exit 1; }

[[ "$BACKEND_PORT" == "8080" ]] \
  && echo "PASS: Ingress backend port is 8080" \
  || { echo "FAIL: Ingress backend port mismatch"; exit 1; }

# 4. Endpoint validation
ENDPOINTS=$($KUBECTL get endpoints "$SVC" -n "$NS" \
  -o jsonpath='{.subsets[*].addresses[*].ip}')

[[ -n "$ENDPOINTS" ]] \
  && echo "PASS: Service has active endpoints" \
  || { echo "FAIL: Service has no endpoints"; exit 1; }

echo "=== VALIDATION COMPLETE ==="
echo "Ingress and Service configuration is CORRECT"
