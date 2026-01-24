#!/bin/bash
# Alternative: Install Karmada using Helm (more reliable with K3s)
# Run this on vps9 (Singapore cluster)

set -e

echo "=== Karmada Installation using Helm ==="
echo "Host: Singapore cluster (vps9)"
echo "Member clusters: vn, vn2, us, eu, jp"
echo ""

# Configuration
KARMADA_VERSION="v1.14.1"
KARMADA_NAMESPACE="karmada-system"
SETUP_DIR="/root/karmada-setup"

# Step 1: Install Helm if not present
echo "=== Step 1: Installing Helm ==="
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm already installed"
fi
helm version

# Step 2: Add Karmada Helm repository
echo ""
echo "=== Step 2: Adding Karmada Helm Repository ==="
helm repo add karmada-charts https://raw.githubusercontent.com/karmada-io/karmada/master/charts
helm repo update

# Step 3: Create namespace
echo ""
echo "=== Step 3: Creating Karmada Namespace ==="
kubectl create namespace $KARMADA_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Step 4: Create values file for K3s compatibility
echo ""
echo "=== Step 4: Creating Helm Values Configuration ==="
cat > $SETUP_DIR/configs/karmada-values.yaml << EOF
# Karmada Helm values for K3s
installMode: "host"
controllerManager:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

scheduler:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

webhook:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

apiServer:
  replicas: 1
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 256Mi
  hostNetwork: false
  serviceType: ClusterIP

etcd:
  mode: "internal"
  internal:
    replicas: 1
    storageMode: "hostPath"
    hostPath: "/var/lib/karmada-etcd"
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi

# External access configuration
apiServer:
  servicePort: 5443
  certSANs:
    - "10.10.0.9"
    - "46.250.232.0"
    - "vps9.canhnv.com"
    - "localhost"
    - "127.0.0.1"
EOF

# Step 5: Install Karmada
echo ""
echo "=== Step 5: Installing Karmada via Helm ==="
helm install karmada karmada-charts/karmada \
  --namespace $KARMADA_NAMESPACE \
  --version ${KARMADA_VERSION#v} \
  --values $SETUP_DIR/configs/karmada-values.yaml \
  --wait \
  --timeout 10m

# Step 6: Check installation status
echo ""
echo "=== Step 6: Checking Installation Status ==="
kubectl get pods -n $KARMADA_NAMESPACE
kubectl get svc -n $KARMADA_NAMESPACE

# Step 7: Get Karmada kubeconfig
echo ""
echo "=== Step 7: Extracting Karmada Kubeconfig ==="
kubectl get secret -n $KARMADA_NAMESPACE karmada-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > $SETUP_DIR/configs/karmada-kubeconfig

# Update the server address in kubeconfig
sed -i "s|https://.*:5443|https://10.10.0.9:5443|g" $SETUP_DIR/configs/karmada-kubeconfig

# Step 8: Install karmadactl
echo ""
echo "=== Step 8: Installing karmadactl ==="
if ! command -v karmadactl &> /dev/null; then
    echo "Installing karmadactl v${KARMADA_VERSION}..."
    curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash -s ${KARMADA_VERSION}
fi

# Step 9: Test Karmada API
echo ""
echo "=== Step 9: Testing Karmada API ==="
export KUBECONFIG=$SETUP_DIR/configs/karmada-kubeconfig
if kubectl get clusters &>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "✗ Karmada API test failed"
    kubectl get svc -n $KARMADA_NAMESPACE
    exit 1
fi

# Step 10: Create helper scripts
echo ""
echo "=== Step 10: Creating Helper Scripts ==="

# Status check script
cat > $SETUP_DIR/scripts/check-karmada-helm-status.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Helm Installation Status ==="
echo ""
echo "Helm Release:"
helm list -n karmada-system
echo ""
echo "Pods:"
kubectl get pods -n karmada-system
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
chmod +x $SETUP_DIR/scripts/check-karmada-helm-status.sh

# Create uninstall script
cat > $SETUP_DIR/scripts/uninstall-karmada-helm.sh << 'EOF'
#!/bin/bash
echo "Uninstalling Karmada..."
helm uninstall karmada -n karmada-system
kubectl delete namespace karmada-system --force --grace-period=0
echo "Karmada uninstalled"
EOF
chmod +x $SETUP_DIR/scripts/uninstall-karmada-helm.sh

echo ""
echo "✓ Karmada installation via Helm completed!"
echo ""
echo "Karmada API endpoint: https://10.10.0.9:5443"
echo "Kubeconfig: $SETUP_DIR/configs/karmada-kubeconfig"
echo ""
echo "Next steps:"
echo "1. Transfer member cluster kubeconfigs"
echo "2. Run 03-join-clusters.sh"
echo ""
echo "To check status: $SETUP_DIR/scripts/check-karmada-helm-status.sh"
echo "To uninstall: $SETUP_DIR/scripts/uninstall-karmada-helm.sh"
