#!/bin/bash
# Script to force cleanup stuck Karmada namespace
# Run this on vps9

echo "=== Force Cleanup Karmada Namespace ==="
echo ""

# Step 1: Delete all resources in the namespace
echo "Step 1: Deleting all resources in karmada-system namespace..."
kubectl delete all --all -n karmada-system --force --grace-period=0 2>/dev/null || true

# Step 2: Remove finalizers from namespace
echo ""
echo "Step 2: Removing finalizers from namespace..."
kubectl get namespace karmada-system -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/karmada-system/finalize" -f - 2>/dev/null || true

# Step 3: Patch the namespace to remove finalizers
echo ""
echo "Step 3: Patching namespace to remove kubernetes finalizer..."
kubectl patch namespace karmada-system -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

# Step 4: Force delete stuck resources
echo ""
echo "Step 4: Force deleting any stuck resources..."
for resource in $(kubectl api-resources --namespaced=true -o name); do
  kubectl delete $resource --all -n karmada-system --force --grace-period=0 2>/dev/null || true
done

# Step 5: Remove any remaining CRDs
echo ""
echo "Step 5: Removing Karmada CRDs if any..."
kubectl delete crd $(kubectl get crd | grep karmada | awk '{print $1}') 2>/dev/null || true

# Step 6: Final namespace deletion attempt
echo ""
echo "Step 6: Final namespace deletion..."
kubectl delete namespace karmada-system --force --grace-period=0 2>/dev/null || true

# Step 7: Check if namespace is gone
echo ""
echo "Checking namespace status..."
if kubectl get namespace karmada-system 2>/dev/null; then
  echo "⚠️  Namespace still exists. Manual intervention may be needed."
  echo ""
  echo "Try these commands manually:"
  echo "1. kubectl proxy &"
  echo "2. curl -k -H 'Content-Type: application/json' -X PUT --data-binary @- http://127.0.0.1:8001/api/v1/namespaces/karmada-system/finalize << EOF"
  echo '{
    "kind": "Namespace",
    "apiVersion": "v1",
    "metadata": {
      "name": "karmada-system"
    },
    "spec": {
      "finalizers": []
    }
  }'
  echo "EOF"
else
  echo "✓ Namespace successfully deleted!"
fi

echo ""
echo "Cleanup complete. You can now run the Karmada installation script."