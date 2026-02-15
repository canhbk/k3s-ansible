# Step 3: Prepare Kubeconfig Files for Member Clusters

This document guides you through preparing kubeconfig files for all member clusters that will join Karmada.

## 3.1 Understanding Member Clusters

Based on your infrastructure, you'll prepare configs for these clusters:

- **sg** (Singapore): Control plane at vps9 (10.10.0.9)
- **sg2** (Singapore 2): Control plane at vps20 (10.10.0.20)
- **vn** (Vietnam 1): Control plane at vps22 (10.10.0.22)
- **vn2** (Vietnam 2): Control plane at vps29 (10.10.0.29)
- **eu** (Europe): Control plane at vps34 (10.10.0.34)
- **jp** (Japan): Control plane at vps3 (10.10.0.3)
- **dev** (Development): To be confirmed

## 3.2 Access Your Local Machine

First, we need to get kubeconfig files from your local machine. On your **local machine** (not vps26):

```bash
# Check available contexts
kubectl config get-contexts

# You should see contexts like:
# CURRENT   NAME   CLUSTER   AUTHINFO   NAMESPACE
# *         dev    dev       dev
#           eu     eu        eu
#           jp     jp        jp
#           sg     sg        sg
#           us     us        us
#           vn     vn        vn
#           vn2    vn2       vn2
```

## 3.3 Export Individual Kubeconfig Files

On your **local machine**, create individual kubeconfig files:

```bash
# Create a directory for kubeconfigs
mkdir -p ~/karmada-kubeconfigs

# Export each cluster's kubeconfig (excluding 'us' as it's the host cluster)
for context in sg sg2 vn vn2 eu jp; do
  echo "Exporting kubeconfig for $context..."
  kubectl config view --minify --flatten --context=$context > ~/karmada-kubeconfigs/kubeconfig-$context
done

# List exported files
ls -la ~/karmada-kubeconfigs/
```

## 3.4 Transfer Kubeconfigs to United States Cluster

Transfer the kubeconfig files to vps26:

```bash
# From your local machine, transfer files to vps26 using SSH config and key-based auth
scp ~/karmada-kubeconfigs/kubeconfig-* vps26:~/karmada-setup/configs/
```

## 3.5 Verify Kubeconfigs on vps26

Now SSH back to vps26 and verify the files:

```bash
# On vps26
cd /root/karmada-setup/configs

# List transferred files
ls -la kubeconfig-*

# Should show:
# kubeconfig-eu
# kubeconfig-jp
# kubeconfig-us
# kubeconfig-vn
# kubeconfig-vn2
```

## 3.6 Test Each Kubeconfig

Create a script to test connectivity to each cluster:

```bash
cat > /root/karmada-setup/scripts/test-kubeconfigs.sh << 'EOF'
#!/bin/bash
echo "=== Testing Kubeconfig Files ==="

cd /root/karmada-setup/configs

for config in kubeconfig-*; do
    if [[ -f "$config" ]]; then
        cluster=${config#kubeconfig-}
        echo -n "Testing $cluster cluster: "

        if kubectl --kubeconfig=$config get nodes &>/dev/null; then
            node_count=$(kubectl --kubeconfig=$config get nodes --no-headers | wc -l)
            echo "✓ Connected ($node_count nodes)"
        else
            echo "✗ Failed to connect"
        fi
    fi
done
EOF

chmod +x /root/karmada-setup/scripts/test-kubeconfigs.sh
/root/karmada-setup/scripts/test-kubeconfigs.sh
```

## 3.7 Get Cluster Information

Gather information about each cluster:

```bash
cat > /root/karmada-setup/scripts/get-cluster-info.sh << 'EOF'
#!/bin/bash
echo "=== Cluster Information ==="

cd /root/karmada-setup/configs

for config in kubeconfig-*; do
    if [[ -f "$config" ]]; then
        cluster=${config#kubeconfig-}
        echo -e "\n--- $cluster cluster ---"

        # Get server URL
        server=$(kubectl --kubeconfig=$config config view --minify -o jsonpath='{.clusters[0].cluster.server}')
        echo "API Server: $server"

        # Get nodes
        echo "Nodes:"
        kubectl --kubeconfig=$config get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion,INTERNAL-IP:.status.addresses[0].address,EXTERNAL-IP:.status.addresses[1].address 2>/dev/null || echo "Failed to get nodes"

        # Get cluster CIDR info if available
        echo "Network Info:"
        kubectl --kubeconfig=$config get cm -n kube-system kubeadm-config -o yaml 2>/dev/null | grep -E "podSubnet|serviceSubnet" || echo "Using default K3s network configuration"
    fi
done
EOF

chmod +x /root/karmada-setup/scripts/get-cluster-info.sh
/root/karmada-setup/scripts/get-cluster-info.sh > /root/karmada-setup/configs/cluster-inventory.txt
cat /root/karmada-setup/configs/cluster-inventory.txt
```

## 3.8 Modify Kubeconfigs for Karmada

Karmada needs to access clusters via their internal (WireGuard) IPs. Create a script to update the server URLs:

```bash
cat > /root/karmada-setup/scripts/update-kubeconfig-urls.sh << 'EOF'
#!/bin/bash
echo "=== Updating Kubeconfig URLs to Use WireGuard IPs ==="

cd /root/karmada-setup/configs

# Define cluster to WireGuard IP mapping
declare -A cluster_ips=(
    ["sg"]="10.10.0.9"
    ["sg2"]="10.10.0.20"
    ["vn"]="10.10.0.22"
    ["vn2"]="10.10.0.29"
    ["eu"]="10.10.0.34"
    ["jp"]="10.10.0.3"
)

for config in kubeconfig-*; do
    if [[ -f "$config" ]]; then
        cluster=${config#kubeconfig-}
        if [[ -n "${cluster_ips[$cluster]}" ]]; then
            echo "Updating $cluster to use ${cluster_ips[$cluster]}:6443"

            # Backup original
            cp $config ${config}.original

            # Update server URL to use WireGuard IP
            sed -i "s|server: https://[^:]*:[0-9]*|server: https://${cluster_ips[$cluster]}:6443|g" $config

            # Verify the change
            new_server=$(kubectl --kubeconfig=$config config view --minify -o jsonpath='{.clusters[0].cluster.server}')
            echo "  New server URL: $new_server"
        fi
    fi
done
EOF

chmod +x /root/karmada-setup/scripts/update-kubeconfig-urls.sh
/root/karmada-setup/scripts/update-kubeconfig-urls.sh
```

## 3.9 Final Verification

Test the updated kubeconfigs:

```bash
# Re-run connectivity test
/root/karmada-setup/scripts/test-kubeconfigs.sh

# All clusters should show "✓ Connected"
```

## 3.10 Create Cluster Registry

Document all clusters for Karmada registration:

```bash
cat > /root/karmada-setup/configs/cluster-registry.yaml << 'EOF'
# Karmada Cluster Registry
# This file documents all clusters to be joined to Karmada

clusters:
  - name: vn
    displayName: "Vietnam 1"
    kubeconfig: kubeconfig-vn
    endpoint: https://10.10.0.22:6443
    region: vietnam
    tier: production
    notes: "3 control plane nodes + 1 storage node"

  - name: vn2
    displayName: "Vietnam 2"
    kubeconfig: kubeconfig-vn2
    endpoint: https://10.10.0.29:6443
    region: vietnam
    tier: production
    notes: "3 control plane nodes + 1 worker node"

  - name: us
    displayName: "United States"
    kubeconfig: kubeconfig-us
    endpoint: https://10.10.0.26:6443
    region: americas
    tier: production
    notes: "1 control plane + 1 worker node"

  - name: eu
    displayName: "Europe"
    kubeconfig: kubeconfig-eu
    endpoint: https://10.10.0.34:6443
    region: europe
    tier: production
    notes: "1 control plane + 1 worker node"

  - name: jp
    displayName: "Japan"
    kubeconfig: kubeconfig-jp
    endpoint: https://10.10.0.3:6443
    region: asia-pacific
    tier: production
    notes: "1 control plane + 1 worker node"

  # Placeholders for future clusters
  # - name: dev
  #   displayName: "Development"
  #   kubeconfig: kubeconfig-dev
  #   endpoint: TBD
  #   region: TBD
  #   tier: development
  #
  # - name: sg2
  #   displayName: "Singapore 2"
  #   kubeconfig: kubeconfig-sg2
  #   endpoint: TBD
  #   region: singapore
  #   tier: production
EOF

echo "Cluster registry created at: /root/karmada-setup/configs/cluster-registry.yaml"
```

## 3.11 Troubleshooting

If any kubeconfig test fails:

```bash
# Check specific cluster connectivity
kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-<cluster> get nodes -v=6

# Common issues:
# 1. Certificate verification failed: The kubeconfig might have the wrong CA
# 2. Connection refused: Check if the WireGuard IP is correct
# 3. Timeout: Verify WireGuard connectivity with: ping <wireguard-ip>

# To bypass certificate verification (NOT for production):
# kubectl --kubeconfig=kubeconfig-<cluster> --insecure-skip-tls-verify get nodes
```

## 3.12 Verification Checklist

Before proceeding to Step 4:

- [ ] All kubeconfig files transferred to vps26
- [ ] Each kubeconfig tested and shows "Connected"
- [ ] Kubeconfigs updated to use WireGuard IPs
- [ ] Cluster information documented in cluster-inventory.txt
- [ ] Cluster registry created

## Summary Script

```bash
cat > /root/karmada-setup/scripts/summarize-kubeconfigs.sh << 'EOF'
#!/bin/bash
echo "=== Kubeconfig Preparation Summary ==="
echo "Location: /root/karmada-setup/configs/"
echo ""
echo "Available Kubeconfigs:"
cd /root/karmada-setup/configs
for config in kubeconfig-*; do
    if [[ -f "$config" && ! "$config" =~ \.original$ ]]; then
        cluster=${config#kubeconfig-}
        server=$(kubectl --kubeconfig=$config config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
        echo "- $cluster: $server"
    fi
done
echo ""
echo "Ready clusters: $(ls kubeconfig-* 2>/dev/null | grep -v ".original" | wc -l)"
EOF

chmod +x /root/karmada-setup/scripts/summarize-kubeconfigs.sh
/root/karmada-setup/scripts/summarize-kubeconfigs.sh
```

## Next Step

With all kubeconfig files prepared and verified, proceed to [Step 4: Join Clusters](./step-4-join-clusters.md)
