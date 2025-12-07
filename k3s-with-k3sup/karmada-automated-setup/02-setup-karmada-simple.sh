#!/bin/bash
# Simple Karmada installation using kubectl and YAML manifests
# Run this on vps9 (Singapore cluster)

set -e

echo "=== Simple Karmada Installation ==="
echo "Host: Singapore cluster (vps9)"
echo ""

# Configuration
KARMADA_VERSION="v1.14.1"
SETUP_DIR="/root/karmada-setup"
KARMADA_NAMESPACE="karmada-system"

# Step 1: Clean up any existing installation
echo "=== Step 1: Cleaning Up ==="
kubectl delete namespace $KARMADA_NAMESPACE --ignore-not-found=true --wait=false || true
sleep 5

# Step 2: Install karmadactl
echo ""
echo "=== Step 2: Installing karmadactl ==="
if ! command -v karmadactl &> /dev/null; then
    # Download karmadactl binary directly
    wget -q https://github.com/karmada-io/karmada/releases/download/${KARMADA_VERSION}/karmadactl-linux-amd64.tgz
    tar -zxf karmadactl-linux-amd64.tgz
    mv karmadactl /usr/local/bin/
    chmod +x /usr/local/bin/karmadactl
    rm -f karmadactl-linux-amd64.tgz
fi
karmadactl version

# Step 3: Create a simple init configuration
echo ""
echo "=== Step 3: Creating Init Configuration ==="
mkdir -p $SETUP_DIR/configs

# Get node internal IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Using node IP: $NODE_IP"

cat > $SETUP_DIR/configs/karmada-init.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $KARMADA_NAMESPACE
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karmada
  namespace: $KARMADA_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karmada
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: karmada
  namespace: $KARMADA_NAMESPACE
EOF

# Apply the basic setup
kubectl apply -f $SETUP_DIR/configs/karmada-init.yaml

# Step 4: Initialize Karmada with minimal configuration
echo ""
echo "=== Step 4: Initializing Karmada ==="

# Create init script with retry logic
cat > $SETUP_DIR/scripts/init-karmada.sh << 'EOF'
#!/bin/bash
set -e

echo "Initializing Karmada..."

# Try different storage modes
for storage_mode in "hostPath" "emptyDir"; do
    echo "Trying with storage mode: $storage_mode"
    
    if karmadactl init \
        --karmada-apiserver-advertise-address=10.10.0.9 \
        --etcd-storage-mode=$storage_mode \
        --karmada-apiserver-replicas=1 \
        --karmada-controller-manager-replicas=1 \
        --karmada-scheduler-replicas=1 \
        --karmada-webhook-replicas=1 \
        --etcd-replicas=1 \
        --karmada-apiserver-service-type=ClusterIP; then
        echo "Successfully initialized with $storage_mode"
        break
    else
        echo "Failed with $storage_mode, trying next..."
        kubectl delete namespace karmada-system --ignore-not-found=true || true
        sleep 10
    fi
done
EOF

chmod +x $SETUP_DIR/scripts/init-karmada.sh

# Run the init script
$SETUP_DIR/scripts/init-karmada.sh

# Step 5: Wait for components
echo ""
echo "=== Step 5: Waiting for Components ==="
sleep 30

# Check status
kubectl get pods -n $KARMADA_NAMESPACE

# Step 6: Get kubeconfig
echo ""
echo "=== Step 6: Setting up Kubeconfig ==="
if [ -f /etc/karmada/karmada-apiserver.config ]; then
    cp /etc/karmada/karmada-apiserver.config $SETUP_DIR/configs/karmada-kubeconfig
    echo "✓ Karmada kubeconfig saved"
else
    echo "⚠️  Karmada kubeconfig not found, checking for secret..."
    kubectl get secret -n $KARMADA_NAMESPACE karmada-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > $SETUP_DIR/configs/karmada-kubeconfig || echo "Failed to get kubeconfig"
fi

# Update server address
if [ -f $SETUP_DIR/configs/karmada-kubeconfig ]; then
    sed -i "s|https://.*:5443|https://10.10.0.9:5443|g" $SETUP_DIR/configs/karmada-kubeconfig
fi

# Step 7: Create port-forward script for testing
echo ""
echo "=== Step 7: Creating Access Script ==="
cat > $SETUP_DIR/scripts/karmada-port-forward.sh << 'EOF'
#!/bin/bash
echo "Setting up port-forward to Karmada API server..."
kubectl port-forward -n karmada-system svc/karmada-apiserver 5443:5443 --address 0.0.0.0 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
echo ""
echo "You can now access Karmada API at: https://10.10.0.9:5443"
echo "To stop: kill $PF_PID"
echo ""
echo "Testing connection..."
sleep 3
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig get clusters --insecure-skip-tls-verify
EOF
chmod +x $SETUP_DIR/scripts/karmada-port-forward.sh

# Step 8: Summary
echo ""
echo "=== Installation Summary ==="
echo "Karmada components status:"
kubectl get pods -n $KARMADA_NAMESPACE --no-headers | awk '{print "- " $1 ": " $3}'
echo ""
echo "Services:"
kubectl get svc -n $KARMADA_NAMESPACE
echo ""
echo "Next steps:"
echo "1. Test access: $SETUP_DIR/scripts/karmada-port-forward.sh"
echo "2. Transfer member cluster kubeconfigs"
echo "3. Run join-clusters.sh"
echo ""
echo "If installation failed, check logs:"
echo "  kubectl logs -n $KARMADA_NAMESPACE -l app=karmada-apiserver"