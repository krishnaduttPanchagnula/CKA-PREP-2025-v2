#!/bin/bash

PC_NAME="high-priority"
DEPLOYMENT="busybox-logger"
NAMESPACE="priority"

echo "Validating PriorityClass and Deployment configuration..."
echo "--------------------------------------------------------"

# Check PriorityClass exists
if ! kubectl get priorityclass "$PC_NAME" &>/dev/null; then
  echo "FAIL: PriorityClass '$PC_NAME' does not exist"
  exit 1
fi
echo "PASS: PriorityClass '$PC_NAME' exists"

# Get highest user-defined PriorityClass value
HIGHEST_VALUE=$(kubectl get priorityclass -o json \
  | jq -r '.items[]
    | select(.metadata.name != "system-node-critical")
    | select(.metadata.name != "system-cluster-critical")
    | select(.globalDefault != true)
    | .value' \
  | sort -n | tail -1)

if [[ -z "$HIGHEST_VALUE" ]]; then
  echo "FAIL: No user-defined PriorityClass found"
  exit 1
fi

# Get high-priority value
HP_VALUE=$(kubectl get priorityclass "$PC_NAME" -o jsonpath='{.value}')
EXPECTED_VALUE=$((HIGHEST_VALUE - 1))

if [[ "$HP_VALUE" != "$EXPECTED_VALUE" ]]; then
  echo "FAIL: PriorityClass value is $HP_VALUE, expected $EXPECTED_VALUE"
  exit 1
fi
echo "PASS: PriorityClass value is correct ($HP_VALUE)"

# Validate deployment priorityClassName
DEPLOYMENT_PC=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.priorityClassName}')

if [[ "$DEPLOYMENT_PC" != "$PC_NAME" ]]; then
  echo "FAIL: Deployment uses priorityClass '$DEPLOYMENT_PC', expected '$PC_NAME'"
  exit 1
fi
echo "PASS: Deployment patched with correct PriorityClass"

echo "--------------------------------------------------------"
echo "SUCCESS: All validations passed"
exit 0
