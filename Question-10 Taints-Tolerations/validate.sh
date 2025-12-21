#!/bin/bash

NODE="node01"
TAINT_KEY="PERMISSION"
TAINT_VALUE="granted"
TAINT_EFFECT="NoSchedule"

echo "Validating taint and toleration configuration..."
echo "------------------------------------------------"

# Validate taint on node01
TAINT_FOUND=$(kubectl get node "$NODE" -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}' \
  | grep "^${TAINT_KEY}=${TAINT_VALUE}:${TAINT_EFFECT}$")

if [[ -z "$TAINT_FOUND" ]]; then
  echo "FAIL: Required taint ${TAINT_KEY}=${TAINT_VALUE}:${TAINT_EFFECT} not found on $NODE"
  exit 1
fi
echo "PASS: Correct taint found on $NODE"

# Find pod scheduled on node01
POD_NAME=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.nodeName}{"\n"}{end}' \
  | awk "\$3==\"$NODE\" {print \$1 \"/\" \$2}" | head -n 1)

if [[ -z "$POD_NAME" ]]; then
  echo "FAIL: No pod is scheduled on $NODE"
  exit 1
fi
echo "PASS: Pod scheduled on $NODE -> $POD_NAME"

NAMESPACE=$(echo "$POD_NAME" | cut -d/ -f1)
NAME=$(echo "$POD_NAME" | cut -d/ -f2)

# Validate toleration in pod spec
TOLERATION_FOUND=$(kubectl get pod "$NAME" -n "$NAMESPACE" \
  -o jsonpath='{range .spec.tolerations[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}' \
  | grep "^${TAINT_KEY}=${TAINT_VALUE}:${TAINT_EFFECT}$")

if [[ -z "$TOLERATION_FOUND" ]]; then
  echo "FAIL: Pod $POD_NAME does not have the required toleration"
  exit 1
fi
echo "PASS: Pod has correct toleration"

echo "------------------------------------------------"
echo "SUCCESS: Taint and toleration validated correctly"
exit 0
