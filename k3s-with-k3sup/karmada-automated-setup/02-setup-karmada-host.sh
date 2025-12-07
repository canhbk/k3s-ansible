#!/bin/bash
# Script to set up Karmada control plane on Singapore cluster
# Run this on vps9 (Singapore cluster)

set -e

echo "=== Karmada Control Plane Setup Script ==="
echo "Host: Singapore cluster (vps9)"
echo "Member clusters: vn, vn2, us, eu, jp"
echo ""

# Configuration
KARMADA_VERSION="1.14.1"
KARMADA_NAMESPACE="karmada-system"
SETUP_DIR="/root/karmada-setup"

# Step 1: Verify prerequisites
echo "=== Step 1: Verifying Prerequisites ==="
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

# Step 2: Create setup directories
echo ""
echo "=== Step 2: Creating Setup Directories ==="
mkdir -p $SETUP_DIR/{configs,scripts,backups,policies}
cd $SETUP_DIR

# Backup current K3s config
cp /etc/rancher/k3s/k3s.yaml $SETUP_DIR/backups/k3s.yaml.$(date +%Y%m%d_%H%M%S)

# Step 3: Install karmadactl
echo ""
echo "=== Step 3: Installing Karmadactl ==="
if ! command -v karmadactl &> /dev/null; then
    echo "Installing karmadactl v${KARMADA_VERSION}..."
    curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=${KARMADA_VERSION} bash
else
    echo "karmadactl already installed"
fi
karmadactl version

# Step 4: Initialize Karmada (Development mode with single replicas)
echo ""
echo "=== Step 4: Initializing Karmada Control Plane ==="
echo "Using development mode (single replica) for resource efficiency"

karmadactl init \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace $KARMADA_NAMESPACE \
  --etcd-storage-mode PVC \
  --storage-classes-name local-path \
  --etcd-replicas=1 \
  --karmada-apiserver-replicas=1 \
  --karmada-controller-manager-replicas=1 \
  --karmada-scheduler-replicas=1 \
  --karmada-webhook-replicas=1 \
  --cert-external-ip=10.10.0.9,46.250.232.0 \
  --cert-external-dns=vps9.canhnv.com

# Step 5: Wait for Karmada to be ready
echo ""
echo "=== Step 5: Waiting for Karmada Components ==="
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n $KARMADA_NAMESPACE --timeout=300s

# Step 6: Verify installation
echo ""
echo "=== Step 6: Verifying Karmada Installation ==="
kubectl get pods -n $KARMADA_NAMESPACE
kubectl get svc -n $KARMADA_NAMESPACE

# Step 7: Set up Karmada kubeconfig
echo ""
echo "=== Step 7: Setting up Karmada Kubeconfig ==="
cp /etc/karmada/karmada-apiserver.config $SETUP_DIR/configs/karmada-kubeconfig

# Test Karmada API
if kubectl --kubeconfig=$SETUP_DIR/configs/karmada-kubeconfig get clusters &>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "✗ Karmada API test failed"
    exit 1
fi

# Step 8: Create helper scripts
echo ""
echo "=== Step 8: Creating Helper Scripts ==="

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
Member Clusters: vn, vn2, us, eu, jp
Excluded Clusters: dev, sg2

Karmada API Server:
- Internal: https://$(kubectl get svc -n karmada-system karmada-apiserver -o jsonpath='{.spec.clusterIP}'):5443
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