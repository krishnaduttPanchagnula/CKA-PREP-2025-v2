#!/bin/bash
#!/bin/bash

NAMESPACE="mariadb"
PVC_NAME="mariadb"
DEPLOYMENT_NAME="mariadb"

echo "Validating PersistentVolumeClaim..."

pvc_exists=$(kubectl get pvc -n $NAMESPACE $PVC_NAME --ignore-not-found)
if [ -z "$pvc_exists" ]; then
  echo "PVC '$PVC_NAME' does not exist in namespace '$NAMESPACE'. Validation failed."
  exit 1
fi

# Check PVC access modes and storage size
access_mode=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.accessModes[0]}')
storage_size=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')

if [ "$access_mode" != "ReadWriteOnce" ]; then
  echo "PVC '$PVC_NAME' has wrong access mode: $access_mode. Expected: ReadWriteOnce"
  exit 1
fi

if [ "$storage_size" != "250Mi" ]; then
  echo "PVC '$PVC_NAME' has wrong storage size: $storage_size. Expected: 250Mi"
  exit 1
fi

echo "PVC validation successful."

echo "Validating MariaDB Deployment..."

deployment_exists=$(kubectl get deployment -n $NAMESPACE $DEPLOYMENT_NAME --ignore-not-found)
if [ -z "$deployment_exists" ]; then
  echo "Deployment '$DEPLOYMENT_NAME' does not exist in namespace '$NAMESPACE'. Validation failed."
  exit 1
fi

# Check if Deployment uses PVC in volume mounts
volume_pvc_ref=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath="{.spec.template.spec.volumes[?(@.persistentVolumeClaim.claimName=='$PVC_NAME')]}")
if [ -z "$volume_pvc_ref" ]; then
  echo "Deployment '$DEPLOYMENT_NAME' does not reference PVC '$PVC_NAME'. Validation failed."
  exit 1
fi

# Check Deployment readiness
desired_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
ready_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')

if [ "$ready_replicas" != "$desired_replicas" ]; then
  echo "Deployment '$DEPLOYMENT_NAME' is not fully ready. Ready replicas: $ready_replicas, Desired replicas: $desired_replicas"
  exit 1
fi

echo "MariaDB Deployment is running and stable."

echo "All validations passed."

exit 0
