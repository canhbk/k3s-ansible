#!/bin/bash

# Script to force delete a Kubernetes namespace stuck in Terminating status
# Usage: ./force-delete-namespace.sh <namespace-name>

set -e

# Check if namespace name is provided
if [ $# -eq 0 ]; then
    echo "Error: No namespace name provided"
    echo "Usage: $0 <namespace-name>"
    exit 1
fi

NAMESPACE=$1

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl command not found"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Error: Namespace '$NAMESPACE' does not exist"
    exit 1
fi

echo "Attempting to force delete namespace: $NAMESPACE"

# Get the namespace JSON and remove finalizers
echo "Removing finalizers from namespace..."
kubectl get namespace "$NAMESPACE" -o json | \
    jq '.spec.finalizers = []' | \
    kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -

# Wait a moment for the namespace to be deleted
sleep 2

# Check if namespace still exists
if kubectl get namespace "$NAMESPACE" &> /dev/null 2>&1; then
    echo "Warning: Namespace still exists. Attempting to patch metadata.finalizers..."
    kubectl patch namespace "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge
else
    echo "Success: Namespace '$NAMESPACE' has been deleted"
fi

# Final check
sleep 2
if kubectl get namespace "$NAMESPACE" &> /dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' still exists after force deletion attempt"
    echo "You may need to manually edit the namespace and remove finalizers"
    exit 1
else
    echo "Confirmed: Namespace '$NAMESPACE' has been successfully deleted"
fi