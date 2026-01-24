# Step 1: Prerequisites and Pre-Installation Checks

This document contains all the commands and checks you need to run before installing Karmada on the United States cluster.

## 1.1 Access United States Cluster

First, SSH into the United States control plane node:

```bash
# SSH to vps26 (United States control plane)
ssh root@65.49.60.35

# Or if you have SSH config set up
ssh vps26
```

## 1.2 Verify K3s Cluster Health

Run these commands on vps26:

```bash
# Check if K3s is running
systemctl status k3s

# Check cluster nodes
kubectl get nodes -o wide

# Expected output should show:
# NAME               STATUS   ROLES                       AGE   VERSION
# vps26-optimal-us   Ready    control-plane,etcd,master   ...   v1.32.5+k3s1
# vps27-optimal-us   Ready    <none>                      ...   v1.32.5+k3s1

# Check cluster resources
kubectl top nodes

# Check existing pods
kubectl get pods -A

# Check storage class
kubectl get storageclass
```

## 1.3 Verify Network Configuration

Check WireGuard and network connectivity:

```bash
# Check WireGuard interface
ip addr show wg0

# Should show: 10.10.0.26/24

# Test connectivity to other cluster control planes
echo "=== Testing connectivity to member clusters ==="
echo "SG cluster (vps9):"
nc -zv 10.10.0.9 6443

echo "SG2 cluster (vps20):"
nc -zv 10.10.0.20 6443

echo "VN cluster (vps22):"
nc -zv 10.10.0.22 6443

echo "VN2 cluster (vps29):"
nc -zv 10.10.0.29 6443

echo "EU cluster (vps34):"
nc -zv 10.10.0.34 6443

echo "JP cluster (vps3):"
nc -zv 10.10.0.3 6443
```

## 1.4 Check System Resources

Ensure United States cluster has enough resources for Karmada:

```bash
# Check CPU and Memory
free -h
nproc
df -h

# Minimum requirements:
# - 2 CPU cores (4 recommended)
# - 4GB RAM (8GB recommended)  
# - 20GB free disk space
```

## 1.5 Backup Current Configuration

Before making changes, backup important configs:

```bash
# Create backup directory
mkdir -p $HOME/karmada-setup/backups
cd $HOME/karmada-setup/backups

# Backup K3s config
cp /etc/rancher/k3s/k3s.yaml k3s.yaml.backup

# List current contexts
kubectl config get-contexts > contexts.backup

# Export current deployments
kubectl get deploy -A -o yaml > deployments.backup.yaml
```

## 1.6 Install Required Tools

Install tools needed for Karmada setup:

```bash
# Update package list
apt update

# Install required packages
apt install -y curl wget jq git

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
fi

# Verify kubectl
kubectl version --client
```

## 1.7 DNS Preparation (Optional)

If you want to use DNS for Karmada API:

```bash
# Add DNS entry for Karmada API (optional)
# This would be done in your DNS provider (e.g., Cloudflare)
# Example: us-karmada.canhnv.com -> 65.49.60.35

# Test DNS resolution if configured
# nslookup us-karmada.canhnv.com
```

## 1.8 Create Setup Directory Structure

Prepare directories for Karmada setup:

```bash
# Create main setup directory
mkdir -p $HOME/karmada-setup/{configs,scripts,backups,policies}
cd $HOME/karmada-setup

# Create a setup log
echo "Karmada Setup Started: $(date)" > setup.log
echo "Host Cluster: United States (us)" >> setup.log
echo "Control Plane: vps26 (10.10.0.26)" >> setup.log
```

## 1.9 Verification Checklist

Before proceeding to Step 2, verify:

- [ ] Can SSH to vps26 successfully
- [ ] K3s cluster is healthy (2 nodes ready)
- [ ] WireGuard interface shows 10.10.0.26/24
- [ ] Can reach other clusters via WireGuard (port 6443)
- [ ] System has minimum 2 CPU, 4GB RAM, 20GB disk
- [ ] kubectl is installed and working
- [ ] Backup directory created with K3s config backed up
- [ ] Setup directory structure created

## Commands Summary for Quick Run

```bash
# Quick verification script
cat > $HOME/karmada-setup/verify-prerequisites.sh << 'EOF'
#!/bin/bash
echo "=== K3s Cluster Status ==="
kubectl get nodes -o wide

echo -e "\n=== System Resources ==="
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}')"

echo -e "\n=== Network Connectivity ==="
for cluster in "10.10.0.9:sg" "10.10.0.20:sg2" "10.10.0.22:vn" "10.10.0.29:vn2" "10.10.0.34:eu" "10.10.0.3:jp"; do
    ip=${cluster%:*}
    name=${cluster#*:}
    if nc -zv $ip 6443 2>&1 | grep -q succeeded; then
        echo "✓ $name cluster ($ip): Connected"
    else
        echo "✗ $name cluster ($ip): Failed"
    fi
done

echo -e "\n=== Prerequisites Check Complete ==="
EOF

chmod +x $HOME/karmada-setup/verify-prerequisites.sh
$HOME/karmada-setup/verify-prerequisites.sh
```

## Next Step

Once all prerequisites are verified, proceed to [Step 2: Install Karmada](./step-2-install-karmada.md)