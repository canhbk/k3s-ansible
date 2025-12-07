#!/bin/bash
# Fixed script to set up Karmada control plane on Singapore cluster
# Run this on vps9 (Singapore cluster)

set -e

echo "=== Karmada Control Plane Setup Script (Fixed) ==="
echo "Host: Singapore cluster (vps9)"
echo "Member clusters: vn, vn2, us, eu, jp"
echo ""

# Configuration
KARMADA_VERSION="1.14.1"
KARMADA_NAMESPACE="karmada-system"
SETUP_DIR="/root/karmada-setup"

# Step 1: Clean up any previous failed installation
echo "=== Step 1: Cleaning Up Previous Installation ==="
echo "Removing any existing Karmada installation..."
kubectl delete namespace $KARMADA_NAMESPACE --ignore-not-found=true || true
sleep 10

# Step 2: Verify prerequisites
echo ""
echo "=== Step 2: Verifying Prerequisites ==="
echo -n "Checking K3s cluster health... "
if kubectl get nodes &>/dev/null; then
    echo "✓ K3s is running"
    kubectl get nodes -o wide
else
    echo "✗ K3s is not accessible"
    exit 1
fi

echo -n "Checking WireGuard interface... "
if ip addr show wg0 | grep -q "10.10.0.9"; then
    echo "✓ WireGuard configured (10.10.0.9)"
else
    echo "✗ WireGuard not configured properly"
    exit 1
fi

# Step 3: Create setup directories
echo ""
echo "=== Step 3: Creating Setup Directories ==="
mkdir -p $SETUP_DIR/{configs,scripts,backups,policies}
cd $SETUP_DIR

# Backup current K3s config
cp /etc/rancher/k3s/k3s.yaml $SETUP_DIR/backups/k3s.yaml.$(date +%Y%m%d_%H%M%S)

# Step 4: Install karmadactl
echo ""
echo "=== Step 4: Installing Karmadactl ==="
if ! command -v karmadactl &> /dev/null; then
    echo "Installing karmadactl v${KARMADA_VERSION}..."
    curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=${KARMADA_VERSION} bash
else
    echo "karmadactl already installed"
fi
karmadactl version

# Step 5: Initialize Karmada with host networking for etcd
echo ""
echo "=== Step 5: Initializing Karmada Control Plane (with fixes) ==="
echo "Using development mode with host networking for etcd compatibility"

# Create a temporary kubeconfig without server override
cp /etc/rancher/k3s/k3s.yaml /tmp/k3s-temp.yaml
sed -i 's/127.0.0.1/10.10.0.9/g' /tmp/k3s-temp.yaml

# Initialize Karmada with specific configurations for K3s
karmadactl init \
  --kubeconfig /tmp/k3s-temp.yaml \
  --namespace $KARMADA_NAMESPACE \
  --etcd-storage-mode hostPath \
  --karmada-data-path /var/lib/karmada \
  --etcd-replicas=1 \
  --karmada-apiserver-replicas=1 \
  --karmada-controller-manager-replicas=1 \
  --karmada-scheduler-replicas=1 \
  --karmada-webhook-replicas=1 \
  --cert-external-ip=10.10.0.9,46.250.232.0 \
  --cert-external-dns=vps9.canhnv.com \
  --wait-component-ready-timeout=120

# Step 6: Wait for Karmada to be ready
echo ""
echo "=== Step 6: Waiting for Karmada Components ==="
echo "Waiting for pods to be ready (this may take a few minutes)..."
sleep 30

# Check pod status
kubectl get pods -n $KARMADA_NAMESPACE

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n $KARMADA_NAMESPACE --timeout=300s || {
    echo "Some pods failed to start. Checking logs..."
    kubectl logs -n $KARMADA_NAMESPACE -l app=karmada-apiserver --tail=50
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check etcd pod: kubectl logs -n $KARMADA_NAMESPACE etcd-0"
    echo "2. Check apiserver: kubectl logs -n $KARMADA_NAMESPACE -l app=karmada-apiserver"
    echo "3. Verify storage: kubectl get pvc -n $KARMADA_NAMESPACE"
    exit 1
}

# Step 7: Verify installation
echo ""
echo "=== Step 7: Verifying Karmada Installation ==="
kubectl get pods -n $KARMADA_NAMESPACE
kubectl get svc -n $KARMADA_NAMESPACE

# Step 8: Set up Karmada kubeconfig
echo ""
echo "=== Step 8: Setting up Karmada Kubeconfig ==="
cp /etc/karmada/karmada-apiserver.config $SETUP_DIR/configs/karmada-kubeconfig

# Fix the server address in kubeconfig
sed -i 's/https:\/\/[^:]*:5443/https:\/\/10.10.0.9:5443/g' $SETUP_DIR/configs/karmada-kubeconfig

# Test Karmada API
if kubectl --kubeconfig=$SETUP_DIR/configs/karmada-kubeconfig get clusters &>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "✗ Karmada API test failed"
    echo "Checking Karmada API server service..."
    kubectl get svc -n $KARMADA_NAMESPACE karmada-apiserver
    exit 1
fi

# Step 9: Create helper scripts
echo ""
echo "=== Step 9: Creating Helper Scripts ==="

# Karmada context switcher
cat > $SETUP_DIR/scripts/karmada-context.sh << 'EOF'
#!/bin/bash
case "$1" in
  "karmada")
    export KUBECONFIG=/root/karmada-setup/configs/karmada-kubeconfig
    echo "Switched to Karmada context"
    ;;
  "k3s")
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo "Switched to K3s context"
    ;;
  *)
    echo "Usage: source karmada-context.sh [karmada|k3s]"
    ;;
esac
EOF
chmod +x $SETUP_DIR/scripts/karmada-context.sh

# Karmada status checker
cat > $SETUP_DIR/scripts/check-karmada-status.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Status ==="
echo "Version: $(karmadactl version --short)"
echo ""
echo "Pods:"
kubectl get pods -n karmada-system --no-headers | awk '{printf "%-50s %s\n", $1, $3}'
echo ""
echo "Services:"
kubectl get svc -n karmada-system
echo ""
echo "API Test:"
if kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig get clusters &>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "✗ Karmada API is not accessible"
fi
EOF
chmod +x $SETUP_DIR/scripts/check-karmada-status.sh

# Setup kubectl plugin
mkdir -p ~/.local/bin
ln -sf $(which karmadactl) ~/.local/bin/kubectl-karmada

# Clean up temp file
rm -f /tmp/k3s-temp.yaml

echo ""
echo "=== Installation Summary ==="
cat > $SETUP_DIR/configs/installation-info.txt << EOF
Karmada Installation Details
===========================
Date: $(date)
Host Cluster: Singapore (sg)
Node: vps9 (10.10.0.9 / 46.250.232.0)
Karmada Version: v${KARMADA_VERSION}
Installation Mode: Development (Single Replica)
Storage Mode: hostPath (K3s compatible)
Member Clusters: vn, vn2, us, eu, jp
Excluded Clusters: dev, sg2

Karmada API Server:
- Internal: https://10.10.0.9:5443
- Config: $SETUP_DIR/configs/karmada-kubeconfig

Next Steps:
1. Transfer kubeconfig files for member clusters
2. Run join-clusters.sh script
EOF

cat $SETUP_DIR/configs/installation-info.txt

echo ""
echo "✓ Karmada control plane installation completed!"
echo ""
echo "Next: Transfer kubeconfig files and run join-clusters.sh"