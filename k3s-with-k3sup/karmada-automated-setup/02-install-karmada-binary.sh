#!/bin/bash
# Karmada installation using karmadactl binary
# Run this on vps9 (Singapore cluster)

set -e

echo "=== Karmada Binary Installation ==="
echo "This script installs Karmada using the official karmadactl tool"
echo ""

# Configuration
KARMADA_VERSION="v1.14.1"
SETUP_DIR="/root/karmada-setup"

# Step 1: Verify karmadactl is installed
echo "=== Step 1: Verifying karmadactl ==="
if ! command -v karmadactl &> /dev/null; then
    echo "Installing karmadactl..."
    wget -q https://github.com/karmada-io/karmada/releases/download/${KARMADA_VERSION}/karmadactl-linux-amd64.tgz
    tar -zxf karmadactl-linux-amd64.tgz
    mv karmadactl /usr/local/bin/
    chmod +x /usr/local/bin/karmadactl
    rm -f karmadactl-linux-amd64.tgz
fi
karmadactl version

# Step 2: Check available init options
echo ""
echo "=== Step 2: Checking karmadactl init options ==="
echo "Available options:"
karmadactl init --help | grep -E "^\s+--" | head -20

# Step 3: Initialize Karmada with correct parameters
echo ""
echo "=== Step 3: Initializing Karmada ==="
echo "Using minimal configuration suitable for K3s..."

# Create directories
mkdir -p $SETUP_DIR/{configs,scripts,backups,policies}

# Initialize Karmada
karmadactl init \
  --kubeconfig=/etc/rancher/k3s/k3s.yaml \
  --karmada-apiserver-advertise-address=10.10.0.9 \
  --etcd-storage-mode=hostPath \
  --karmada-apiserver-replicas=1 \
  --karmada-controller-manager-replicas=1 \
  --karmada-scheduler-replicas=1 \
  --karmada-webhook-replicas=1 \
  --etcd-replicas=1 \
  --wait-component-ready-timeout=300

# Step 4: Wait for components to be ready
echo ""
echo "=== Step 4: Waiting for Components ==="
echo "This may take a few minutes..."
sleep 30

# Check pod status
kubectl get pods -n karmada-system

# Step 5: Get Karmada kubeconfig
echo ""
echo "=== Step 5: Setting up Karmada Kubeconfig ==="

# Find the kubeconfig file
if [ -f /etc/karmada/karmada-apiserver.config ]; then
    cp /etc/karmada/karmada-apiserver.config $SETUP_DIR/configs/karmada-kubeconfig
    echo "✓ Found kubeconfig at /etc/karmada/karmada-apiserver.config"
elif [ -f $HOME/.kube/karmada.config ]; then
    cp $HOME/.kube/karmada.config $SETUP_DIR/configs/karmada-kubeconfig
    echo "✓ Found kubeconfig at $HOME/.kube/karmada.config"
elif [ -f /var/lib/karmada/karmada-apiserver.config ]; then
    cp /var/lib/karmada/karmada-apiserver.config $SETUP_DIR/configs/karmada-kubeconfig
    echo "✓ Found kubeconfig at /var/lib/karmada/karmada-apiserver.config"
else
    echo "⚠️  Kubeconfig not found in standard locations"
    echo "Checking for secret..."
    kubectl get secret -n karmada-system karmada-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > $SETUP_DIR/configs/karmada-kubeconfig 2>/dev/null || {
        echo "❌ Failed to get kubeconfig from secret"
        echo "Trying to extract from karmada-apiserver pod..."
        POD=$(kubectl get pods -n karmada-system -l app=karmada-apiserver -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n karmada-system $POD -- cat /etc/karmada/karmada-apiserver.config > $SETUP_DIR/configs/karmada-kubeconfig 2>/dev/null || echo "Failed to extract from pod"
    }
fi

# Update server address in kubeconfig
if [ -f $SETUP_DIR/configs/karmada-kubeconfig ]; then
    sed -i "s|https://.*:5443|https://10.10.0.9:5443|g" $SETUP_DIR/configs/karmada-kubeconfig
    echo "✓ Updated server address in kubeconfig"
fi

# Step 6: Test Karmada API access
echo ""
echo "=== Step 6: Testing Karmada API ==="
export KUBECONFIG=$SETUP_DIR/configs/karmada-kubeconfig
if kubectl get clusters 2>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "⚠️  Direct API access failed, trying with port-forward..."
    
    # Get API server service details
    kubectl get svc -n karmada-system karmada-apiserver
    
    # Create port-forward test script
    cat > $SETUP_DIR/scripts/test-karmada-api.sh << 'EOF'
#!/bin/bash
echo "Testing Karmada API with port-forward..."
kubectl port-forward -n karmada-system svc/karmada-apiserver 5443:5443 &
PF_PID=$!
sleep 3
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig get clusters --server=https://localhost:5443 --insecure-skip-tls-verify
kill $PF_PID
EOF
    chmod +x $SETUP_DIR/scripts/test-karmada-api.sh
    $SETUP_DIR/scripts/test-karmada-api.sh
fi

# Step 7: Create helper scripts
echo ""
echo "=== Step 7: Creating Helper Scripts ==="

# Quick status check
cat > $SETUP_DIR/scripts/karmada-status.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Status ==="
echo ""
echo "Pods:"
kubectl get pods -n karmada-system
echo ""
echo "Services:"
kubectl get svc -n karmada-system
echo ""
echo "API Server Logs (last 10 lines):"
kubectl logs -n karmada-system -l app=karmada-apiserver --tail=10
EOF
chmod +x $SETUP_DIR/scripts/karmada-status.sh

# Kubectl plugin setup
mkdir -p ~/.local/bin
ln -sf $(which karmadactl) ~/.local/bin/kubectl-karmada

# Step 8: Final summary
echo ""
echo "=== Installation Summary ==="
echo ""
echo "Karmada Version: $KARMADA_VERSION"
echo "API Server: https://10.10.0.9:5443"
echo "Kubeconfig: $SETUP_DIR/configs/karmada-kubeconfig"
echo ""
echo "Component Status:"
kubectl get pods -n karmada-system --no-headers | awk '{printf "  %-40s %s\n", $1, $3}'
echo ""
echo "Helper scripts:"
echo "  - Status check: $SETUP_DIR/scripts/karmada-status.sh"
echo "  - API test: $SETUP_DIR/scripts/test-karmada-api.sh"
echo ""
echo "Next steps:"
echo "  1. Verify all pods are Running"
echo "  2. Transfer member cluster kubeconfigs"
echo "  3. Run 03-join-clusters.sh"
echo ""
echo "If pods are not running, check logs with:"
echo "  kubectl logs -n karmada-system <pod-name>"