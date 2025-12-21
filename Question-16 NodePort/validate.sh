#!/bin/bash
set -e

# Resolve kubectl safely
KUBECTL=$(command -v kubectl || true)
if [[ -z "$KUBECTL" ]]; then
  echo "FAIL: kubectl not found"
  exit 1
fi

DEPLOY="nodeport-deployment"
SVC="nodeport-service"

echo "=== NodePort Validation ==="

# 1. Detect namespace of deployment
NS=$($KUBECTL get deploy --all-namespaces \
  -o jsonpath='{range .items[?(@.metadata.name=="nodeport-deployment")]}{.metadata.namespace}{"\n"}{end}')

if [[ -z "$NS" ]]; then
  echo "FAIL: Deployment nodeport-deployment not found"
  exit 1
fi

echo "Detected namespace: $NS"

# 2. Validate container port configuration
PORT=$($KUBECTL get deploy "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')

NAME=$($KUBECTL get deploy "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0].name}')

PROTO=$($KUBECTL get deploy "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0].protocol}')

[[ "$PORT" == "80" ]] \
  && echo "PASS: Container port is 80" \
  || { echo "FAIL: Container port is not 80"; exit 1; }

[[ "$NAME" == "http" ]] \
  && echo "PASS: Container port name is http" \
  || { echo "FAIL: Container port name mismatch"; exit 1; }

[[ "$PROTO" == "TCP" ]] \
  && echo "PASS: Container protocol is TCP" \
  || { echo "FAIL: Container protocol mismatch"; exit 1; }

# 3. Validate Service exists
$KUBECTL get svc "$SVC" -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: Service nodeport-service not found"; exit 1; }

TYPE=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.type}')
SPORT=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].port}')
TPORT=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}')
NPORT=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].nodePort}')
SPROTO=$($KUBECTL get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].protocol}')

[[ "$TYPE" == "NodePort" ]] \
  && echo "PASS: Service type is NodePort" \
  || { echo "FAIL: Service is not NodePort"; exit 1; }

[[ "$SPORT" == "80" ]] \
  && echo "PASS: Service port is 80" \
  || { echo "FAIL: Service port mismatch"; exit 1; }

[[ "$TPORT" == "80" || "$TPORT" == "http" ]] \
  && echo "PASS: TargetPort correctly mapped" \
  || { echo "FAIL: TargetPort incorrect"; exit 1; }

[[ "$NPORT" == "30080" ]] \
  && echo "PASS: NodePort is 30080" \
  || { echo "FAIL: NodePort is not 30080"; exit 1; }

[[ "$SPROTO" == "TCP" ]] \
  && echo "PASS: Service protocol is TCP" \
  || { echo "FAIL: Service protocol mismatch"; exit 1; }

# 4. Validate Service exposes individual pods
ENDPOINTS=$($KUBECTL get endpoints "$SVC" -n "$NS" \
  -o jsonpath='{.subsets[*].addresses[*].ip}')

[[ -n "$ENDPOINTS" ]] \
  && echo "PASS: Service exposes individual pods (endpoints exist)" \
  || { echo "FAIL: No endpoints found for Service"; exit 1; }

echo "=== VALIDATION COMPLETE ==="
echo "NodePort Service configuration is CORRECT"
