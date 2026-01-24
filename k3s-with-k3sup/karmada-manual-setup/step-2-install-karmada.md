# Step 2: Install Karmada on United States Cluster

This document guides you through installing Karmada control plane on the United States (us) cluster.

## 2.1 Install Karmadactl CLI

Run these commands on vps26:

**Note**: If you're running as a non-root user (e.g., client_3419_1), the scripts will automatically handle permissions by:
- Using sudo for karmadactl init when needed
- Storing Karmada data in `$HOME/.karmada` instead of `/etc/karmada`
- All paths use `$HOME` instead of `/root`

```bash
# Navigate to setup directory
cd $HOME/karmada-setup

# Download and install karmadactl
echo "=== Installing karmadactl CLI ==="
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=1.14.1 bash

# Verify installation
karmadactl version

# Expected output:
# version.Info{GitVersion:"v1.14.1", ...}
```

## 2.2 Choose Installation Mode

You have two options. Choose based on your needs:

### Option A: Development/Testing Mode (Recommended for Initial Setup)

Single replica for all components - lighter resource usage:

```bash
# Save this as install-karmada-dev.sh
cat > /root/karmada-setup/scripts/install-karmada-dev.sh << 'EOF'
#!/bin/bash
echo "=== Installing Karmada in Development Mode ==="

# Create karmada data directory if it doesn't exist
mkdir -p $HOME/.karmada

# Run karmadactl with sudo if not root, or specify alternative data path
if [ "$EUID" -ne 0 ]; then
  sudo karmadactl init \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    --karmada-data-path=$HOME/.karmada \
    --namespace karmada-system \
    --etcd-storage-mode PVC \
    --storage-classes-name local-path \
    --etcd-replicas=1 \
    --karmada-apiserver-replicas=1 \
    --karmada-controller-manager-replicas=1 \
    --karmada-scheduler-replicas=1 \
    --karmada-webhook-replicas=1 \
    --cert-external-ip=10.10.0.26,65.49.60.35 \
    --cert-external-dns=vps26.canhnv.com
else
  karmadactl init \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    --namespace karmada-system \
    --etcd-storage-mode PVC \
    --storage-classes-name local-path \
    --etcd-replicas=1 \
    --karmada-apiserver-replicas=1 \
    --karmada-controller-manager-replicas=1 \
    --karmada-scheduler-replicas=1 \
    --karmada-webhook-replicas=1 \
    --cert-external-ip=10.10.0.26,65.49.60.35 \
    --cert-external-dns=vps26.canhnv.com
fi
EOF

chmod +x /root/karmada-setup/scripts/install-karmada-dev.sh
```

### Option B: Production Mode (For Production Use)

Multiple replicas for high availability:

```bash
# Save this as install-karmada-prod.sh
cat > /root/karmada-setup/scripts/install-karmada-prod.sh << 'EOF'
#!/bin/bash
echo "=== Installing Karmada in Production Mode ==="

# Create karmada data directory if it doesn't exist
mkdir -p $HOME/.karmada

# Run karmadactl with sudo if not root, or specify alternative data path
if [ "$EUID" -ne 0 ]; then
  sudo karmadactl init \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    --karmada-data-path=$HOME/.karmada \
    --namespace karmada-system \
    --etcd-storage-mode PVC \
    --storage-classes-name local-path \
    --etcd-replicas=3 \
    --karmada-apiserver-replicas=2 \
    --karmada-controller-manager-replicas=2 \
    --karmada-scheduler-replicas=2 \
    --karmada-webhook-replicas=2 \
    --cert-external-ip=10.10.0.26,65.49.60.35 \
    --cert-external-dns=vps26.canhnv.com
else
  karmadactl init \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    --namespace karmada-system \
    --etcd-storage-mode PVC \
    --storage-classes-name local-path \
    --etcd-replicas=3 \
    --karmada-apiserver-replicas=2 \
    --karmada-controller-manager-replicas=2 \
    --karmada-scheduler-replicas=2 \
    --karmada-webhook-replicas=2 \
    --cert-external-ip=10.10.0.26,65.49.60.35 \
    --cert-external-dns=vps26.canhnv.com
fi
EOF

chmod +x /root/karmada-setup/scripts/install-karmada-prod.sh
```

## 2.3 Execute Karmada Installation

Choose one of the installation scripts:

```bash
# For development/testing setup
/root/karmada-setup/scripts/install-karmada-dev.sh

# OR for production setup
# /root/karmada-setup/scripts/install-karmada-prod.sh
```

The installation will take 3-5 minutes. You'll see output like:

```
⠋ Waiting for karmada-apiserver to be ready...
✓ Karmada API Server is ready
✓ Create karmada kubeconfig
✓ Create karmada-controller-manager
✓ Create karmada-scheduler
✓ Create karmada-webhook
```

## 2.4 Verify Karmada Installation

After installation completes:

```bash
# Check Karmada system pods
echo "=== Karmada System Pods ==="
kubectl get pods -n karmada-system

# All pods should be Running. Example output:
# NAME                                           READY   STATUS
# etcd-0                                        1/1     Running
# karmada-aggregated-apiserver-xxx              1/1     Running
# karmada-apiserver-xxx                         1/1     Running
# karmada-controller-manager-xxx                1/1     Running
# karmada-scheduler-xxx                         1/1     Running
# karmada-webhook-xxx                           1/1     Running

# Check Karmada services
echo -e "\n=== Karmada Services ==="
kubectl get svc -n karmada-system

# Get Karmada API server endpoint
echo -e "\n=== Karmada API Server Endpoint ==="
kubectl get svc -n karmada-system karmada-apiserver -o jsonpath='{.spec.clusterIP}'
```

## 2.5 Configure Karmada Kubeconfig

Karmada creates its own kubeconfig. Set it up for easy access:

```bash
# Copy Karmada kubeconfig based on where it was created
# If running as root:
if [ -f /etc/karmada/karmada-apiserver.config ]; then
    mkdir -p $HOME/.kube
    cp /etc/karmada/karmada-apiserver.config $HOME/karmada-setup/configs/karmada-kubeconfig
# If running as non-root with custom data path:
elif [ -f $HOME/.karmada/karmada-apiserver.config ]; then
    mkdir -p $HOME/karmada-setup/configs
    cp $HOME/.karmada/karmada-apiserver.config $HOME/karmada-setup/configs/karmada-kubeconfig
else
    echo "Error: Cannot find karmada-apiserver.config"
    echo "Check /etc/karmada/ or $HOME/.karmada/"
fi

# Test Karmada API access
kubectl --kubeconfig=$HOME/karmada-setup/configs/karmada-kubeconfig get clusters

# Should return empty list (no error means API is working):
# No resources found
```

## 2.6 Create Karmada Context Helper

Create a helper script for easy context switching:

```bash
cat > $HOME/karmada-setup/scripts/karmada-context.sh << 'EOF'
#!/bin/bash
# Helper script to switch between K3s and Karmada contexts

case "$1" in
  "karmada")
    export KUBECONFIG=$HOME/karmada-setup/configs/karmada-kubeconfig
    echo "Switched to Karmada context"
    kubectl config current-context
    ;;
  "k3s")
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo "Switched to K3s context"
    kubectl config current-context
    ;;
  *)
    echo "Usage: source karmada-context.sh [karmada|k3s]"
    echo "Current KUBECONFIG: $KUBECONFIG"
    ;;
esac
EOF

chmod +x $HOME/karmada-setup/scripts/karmada-context.sh

# Add alias for convenience
echo "alias karmada-ctx='source $HOME/karmada-setup/scripts/karmada-context.sh'" >> ~/.bashrc
source ~/.bashrc
```

## 2.7 Install Karmadactl kubectl Plugin

For easier Karmada operations:

```bash
# The karmadactl can work as kubectl plugin
mkdir -p ~/.local/bin
ln -s $(which karmadactl) ~/.local/bin/kubectl-karmada

# Test the plugin
kubectl karmada version

# Now you can use: kubectl karmada <command>
```

## 2.8 Save Installation Details

Document the installation for future reference:

```bash
cat > $HOME/karmada-setup/configs/installation-info.txt << EOF
Karmada Installation Details
===========================
Date: $(date)
Host Cluster: United States (us)
Node: vps26 (10.10.0.26 / 65.49.60.35)
Karmada Version: v1.14.1
K3s Version: v1.32.5+k3s1
Installation Mode: $(kubectl get deploy -n karmada-system karmada-apiserver -o jsonpath='{.spec.replicas}' | awk '{if ($1==1) print "Development"; else print "Production"}')

Karmada API Server:
- Internal: https://$(kubectl get svc -n karmada-system karmada-apiserver -o jsonpath='{.spec.clusterIP}'):5443
- Config: $HOME/karmada-setup/configs/karmada-kubeconfig

Components Status:
$(kubectl get pods -n karmada-system --no-headers | awk '{print "- " $1 ": " $3}')
EOF

cat $HOME/karmada-setup/configs/installation-info.txt
```

## 2.9 Troubleshooting

If any pods are not running:

```bash
# Check pod logs
kubectl logs -n karmada-system <pod-name>

# Describe pod for events
kubectl describe pod -n karmada-system <pod-name>

# Common issues:
# - Insufficient resources: Check with 'kubectl top nodes'
# - Storage issues: Check PVC with 'kubectl get pvc -n karmada-system'
# - Network issues: Verify firewall/security groups
```

## 2.10 Verification Checklist

Before proceeding to Step 3:

- [ ] karmadactl is installed and shows version
- [ ] All Karmada pods are Running in karmada-system namespace
- [ ] Can access Karmada API with kubeconfig
- [ ] kubectl karmada plugin is working
- [ ] Installation details are documented

## Quick Status Check Script

```bash
cat > $HOME/karmada-setup/scripts/check-karmada-status.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Status Check ==="
echo "Karmada Version: $(karmadactl version --short)"
echo ""
echo "Pod Status:"
kubectl get pods -n karmada-system --no-headers | awk '{printf "%-40s %s\n", $1, $3}'
echo ""
echo "API Test:"
if kubectl --kubeconfig=$HOME/karmada-setup/configs/karmada-kubeconfig get clusters &>/dev/null; then
    echo "✓ Karmada API is accessible"
else
    echo "✗ Karmada API is not accessible"
fi
EOF

chmod +x $HOME/karmada-setup/scripts/check-karmada-status.sh
$HOME/karmada-setup/scripts/check-karmada-status.sh
```

## Next Step

Once Karmada is installed and verified, proceed to [Step 3: Prepare Kubeconfigs](./step-3-prepare-kubeconfigs.md)
