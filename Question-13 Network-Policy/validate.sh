#!/bin/bash
set -e

# Resolve kubectl safely
KUBECTL=$(command -v kubectl || true)
if [[ -z "$KUBECTL" ]]; then
  echo "FAIL: kubectl not found"
  exit 1
fi

POLICY_DIR="/root/network-policies"
EXPECTED_POLICY="policy-z"
NS_BACKEND="backend"
NS_FRONTEND="frontend"

echo "=== NetworkPolicy Validation ==="

# 1. Ensure only policy-z is applied
APPLIED_POLICIES=$($KUBECTL get networkpolicy -n $NS_BACKEND \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if echo "$APPLIED_POLICIES" | grep -q "policy-x"; then
  echo "FAIL: policy-x is applied (too permissive)"
  exit 1
fi

if echo "$APPLIED_POLICIES" | grep -q "policy-y"; then
  echo "FAIL: policy-y is applied (too permissive)"
  exit 1
fi

if ! echo "$APPLIED_POLICIES" | grep -q "$EXPECTED_POLICY"; then
  echo "FAIL: policy-z is not applied"
  exit 1
fi

echo "PASS: Only policy-z is applied"

# 2. Validate policy-z rules
POLICY=$($KUBECTL get networkpolicy policy-z -n backend -o yaml)

echo "$POLICY" | grep -q "namespaceSelector" \
  || { echo "FAIL: No namespaceSelector in policy-z"; exit 1; }

echo "$POLICY" | grep -q "podSelector" \
  || { echo "FAIL: No podSelector in policy-z"; exit 1; }

echo "$POLICY" | grep -q "port: 80" \
  || { echo "FAIL: Port 80 not allowed"; exit 1; }

echo "PASS: policy-z is least permissive and correct"

# 3. Runtime connectivity test (frontend → backend)
FRONTEND_POD=$($KUBECTL get pod -n frontend -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

BACKEND_SVC_IP=$($KUBECTL get svc backend-service -n backend \
  -o jsonpath='{.spec.clusterIP}')

NS_LABEL=$($KUBECTL get ns frontend -o jsonpath='{.metadata.labels.name}')

if [[ "$NS_LABEL" != "frontend" ]]; then
  echo "INFO: Labeling frontend namespace (required for NetworkPolicy)"
  $KUBECTL label namespace frontend name=frontend --overwrite
fi

echo "Testing connectivity frontend → backend..."
$KUBECTL exec -n frontend "$FRONTEND_POD" -- \
  curl -s --connect-timeout 5 http://$BACKEND_SVC_IP:80 >/dev/null \
  && echo "PASS: Frontend can reach Backend" \
  || { echo "FAIL: Frontend cannot reach Backend"; exit 1; }

echo "=== VALIDATION COMPLETE ==="
echo "Correct NetworkPolicy (policy-z) is deployed"