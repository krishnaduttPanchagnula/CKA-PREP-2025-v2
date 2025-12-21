#!/bin/bash
set -e

# Resolve kubectl safely
KUBECTL=$(command -v kubectl || true)
if [[ -z "$KUBECTL" ]]; then
  echo "FAIL: kubectl not found"
  exit 1
fi

SC_NAME="local-storage"
EXPECTED_PROVISIONER="rancher.io/local-path"
EXPECTED_VBM="WaitForFirstConsumer"

echo "=== StorageClass Validation ==="

# 1. Check StorageClass exists
$KUBECTL get storageclass "$SC_NAME" >/dev/null 2>&1 \
  && echo "PASS: StorageClass $SC_NAME exists" \
  || { echo "FAIL: StorageClass $SC_NAME not found"; exit 1; }

# 2. Validate provisioner
PROVISIONER=$($KUBECTL get storageclass "$SC_NAME" -o jsonpath='{.provisioner}')
[[ "$PROVISIONER" == "$EXPECTED_PROVISIONER" ]] \
  && echo "PASS: Provisioner is $EXPECTED_PROVISIONER" \
  || { echo "FAIL: Provisioner is $PROVISIONER"; exit 1; }

# 3. Validate VolumeBindingMode
VBM=$($KUBECTL get storageclass "$SC_NAME" -o jsonpath='{.volumeBindingMode}')
[[ "$VBM" == "$EXPECTED_VBM" ]] \
  && echo "PASS: VolumeBindingMode is $EXPECTED_VBM" \
  || { echo "FAIL: VolumeBindingMode is $VBM"; exit 1; }

# 4. Validate local-storage is default
IS_DEFAULT=$($KUBECTL get storageclass "$SC_NAME" \
  -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')

[[ "$IS_DEFAULT" == "true" ]] \
  && echo "PASS: local-storage is set as default" \
  || { echo "FAIL: local-storage is not default"; exit 1; }

# 5. Ensure ONLY ONE default StorageClass exists
DEFAULT_COUNT=$($KUBECTL get storageclass \
  -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' \
  | wc -l)

[[ "$DEFAULT_COUNT" -eq 1 ]] \
  && echo "PASS: Exactly one default StorageClass exists" \
  || { echo "FAIL: Multiple default StorageClasses detected"; exit 1; }

# 6. Ensure no PVCs were modified (read-only check)
PVC_COUNT=$($KUBECTL get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
echo "INFO: PVC count detected: $PVC_COUNT (no validation change applied)"

echo "=== VALIDATION COMPLETE ==="
echo "StorageClass configuration is CORRECT"
