#!/bin/bash

set -e

echo "=== Gateway API Migration Validation ==="

# Detect namespace of the existing Ingress named 'web'
NS=$(kubectl get ingress --all-namespaces \
  -o jsonpath='{range .items[?(@.metadata.name=="web")]}{.metadata.namespace}{"\n"}{end}')

if [[ -z "$NS" ]]; then
  echo "FAIL: Ingress 'web' not found in any namespace"
  exit 1
fi

echo "Detected namespace: $NS"

# 1. Validate GatewayClass
echo "Checking GatewayClass 'nginx-class'..."
kubectl get gatewayclass nginx-class >/dev/null 2>&1 \
  && echo "PASS: GatewayClass nginx-class exists" \
  || { echo "FAIL: GatewayClass nginx-class not found"; exit 1; }

# 2. Validate Gateway
echo "Checking Gateway 'web-gateway'..."
kubectl get gateway web-gateway -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: Gateway web-gateway not found"; exit 1; }

GC=$(kubectl get gateway web-gateway -n "$NS" -o jsonpath='{.spec.gatewayClassName}')
HOST=$(kubectl get gateway web-gateway -n "$NS" -o jsonpath='{.spec.listeners[0].hostname}')
PROTO=$(kubectl get gateway web-gateway -n "$NS" -o jsonpath='{.spec.listeners[0].protocol}')
TLSMODE=$(kubectl get gateway web-gateway -n "$NS" -o jsonpath='{.spec.listeners[0].tls.mode}')

[[ "$GC" == "nginx-class" ]] \
  && echo "PASS: GatewayClassName is nginx-class" \
  || echo "FAIL: GatewayClassName mismatch"

[[ "$HOST" == "gateway.web.k8s.local" ]] \
  && echo "PASS: Gateway hostname correct" \
  || echo "FAIL: Gateway hostname incorrect"

[[ "$PROTO" == "HTTPS" ]] \
  && echo "PASS: HTTPS listener configured" \
  || echo "FAIL: Listener is not HTTPS"

[[ "$TLSMODE" == "Terminate" ]] \
  && echo "PASS: TLS termination enabled" \
  || echo "FAIL: TLS termination not set"

# 3. Validate HTTPRoute
echo "Checking HTTPRoute 'web-route'..."
kubectl get httproute web-route -n "$NS" >/dev/null 2>&1 \
  || { echo "FAIL: HTTPRoute web-route not found"; exit 1; }

RHOST=$(kubectl get httproute web-route -n "$NS" -o jsonpath='{.spec.hostnames[0]}')

[[ "$RHOST" == "gateway.web.k8s.local" ]] \
  && echo "PASS: HTTPRoute hostname correct" \
  || echo "FAIL: HTTPRoute hostname incorrect"

# 4. Validate Route attachment to Gateway
PARENT=$(kubectl get httproute web-route -n "$NS" \
  -o jsonpath='{.spec.parentRefs[0].name}')

[[ "$PARENT" == "web-gateway" ]] \
  && echo "PASS: HTTPRoute attached to web-gateway" \
  || echo "FAIL: HTTPRoute not attached to web-gateway"

# 5. Validate backend mapping exists
BACKEND=$(kubectl get httproute web-route -n "$NS" \
  -o jsonpath='{.spec.rules[0].backendRefs[0].name}')

[[ -n "$BACKEND" ]] \
  && echo "PASS: Backend service referenced: $BACKEND" \
  || echo "FAIL: No backend service found in HTTPRoute"

echo "=== VALIDATION COMPLETE ==="
echo "Migration from Ingress -> Gateway API is VALID"
