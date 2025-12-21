#!/bin/bash

HPA_NAME="apache-server"
NAMESPACE="autoscale"
DEPLOYMENT_NAME="apache-deployment"

echo "Validating HPA configuration..."
echo "--------------------------------"

# Check if HPA exists
if ! kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "FAIL: HPA '$HPA_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi
echo "PASS: HPA exists"

# Validate target deployment
TARGET_REF=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.scaleTargetRef.name}')
if [[ "$TARGET_REF" != "$DEPLOYMENT_NAME" ]]; then
  echo "FAIL: HPA targets '$TARGET_REF' instead of '$DEPLOYMENT_NAME'"
  exit 1
fi
echo "PASS: Target deployment is correct"

# Validate CPU utilization target
CPU_TARGET=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}')
if [[ "$CPU_TARGET" != "50" ]]; then
  echo "FAIL: CPU target is $CPU_TARGET%, expected 50%"
  exit 1
fi
echo "PASS: CPU utilization target is 50%"

# Validate min replicas
MIN_REPLICAS=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.minReplicas}')
if [[ "$MIN_REPLICAS" != "1" ]]; then
  echo "FAIL: minReplicas is $MIN_REPLICAS, expected 1"
  exit 1
fi
echo "PASS: minReplicas is 1"

# Validate max replicas
MAX_REPLICAS=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.maxReplicas}')
if [[ "$MAX_REPLICAS" != "4" ]]; then
  echo "FAIL: maxReplicas is $MAX_REPLICAS, expected 4"
  exit 1
fi
echo "PASS: maxReplicas is 4"

# Validate downscale stabilization window
DOWNSCALE_WINDOW=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}')
if [[ "$DOWNSCALE_WINDOW" != "30" ]]; then
  echo "FAIL: Downscale stabilization window is $DOWNSCALE_WINDOW seconds, expected 30"
  exit 1
fi
echo "PASS: Downscale stabilization window is 30 seconds"

echo "--------------------------------"
echo "SUCCESS: All HPA validations passed"
exit 0
