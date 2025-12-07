# Step 4: Join Member Clusters to Karmada

This document guides you through joining all member clusters to the Karmada control plane.

## 4.1 Switch to Karmada Context

First, ensure you're using the Karmada kubeconfig:

```bash
# On vps26, set Karmada kubeconfig
export KUBECONFIG=/root/karmada-setup/configs/karmada-kubeconfig

# Verify you're connected to Karmada
kubectl config current-context
kubectl get namespaces | grep karmada-system

# You should see karmada-system namespace
```

## 4.2 Join Clusters One by One

We'll join each cluster individually to track any issues:

### Join Vietnam 1 (vn) Cluster

```bash
# Join vn cluster
kubectl karmada join vn \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-vn \
  --cluster-context=vn \
  --cluster-namespace=karmada-cluster-vn

# Expected output:
# cluster(vn) is joined successfully
```

### Join Vietnam 2 (vn2) Cluster

```bash
# Join vn2 cluster
kubectl karmada join vn2 \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-vn2 \
  --cluster-context=vn2 \
  --cluster-namespace=karmada-cluster-vn2
```

### Join Singapore (sg) Cluster

```bash
# Join sg cluster
kubectl karmada join sg \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-sg \
  --cluster-context=sg \
  --cluster-namespace=karmada-cluster-sg
```

### Join Singapore 2 (sg2) Cluster

```bash
# Join sg2 cluster
kubectl karmada join sg2 \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-sg2 \
  --cluster-context=sg2 \
  --cluster-namespace=karmada-cluster-sg2
```

### Join Europe (eu) Cluster

```bash
# Join eu cluster
kubectl karmada join eu \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-eu \
  --cluster-context=eu \
  --cluster-namespace=karmada-cluster-eu
```

### Join Japan (jp) Cluster

```bash
# Join jp cluster
kubectl karmada join jp \
  --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-jp \
  --cluster-context=jp \
  --cluster-namespace=karmada-cluster-jp
```

## 4.3 Create Batch Join Script

For convenience, create a script to join all clusters at once:

```bash
cat > /root/karmada-setup/scripts/join-all-clusters.sh << 'EOF'
#!/bin/bash
echo "=== Joining All Clusters to Karmada ==="

export KUBECONFIG=/root/karmada-setup/configs/karmada-kubeconfig

# Array of clusters to join
clusters=("sg" "sg2" "vn" "vn2" "eu" "jp")

# Track results
success=0
failed=0

for cluster in "${clusters[@]}"; do
    echo -e "\n--- Joining $cluster cluster ---"
    
    if kubectl karmada join $cluster \
        --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-$cluster \
        --cluster-context=$cluster \
        --cluster-namespace=karmada-cluster-$cluster; then
        echo "✓ $cluster joined successfully"
        ((success++))
    else
        echo "✗ $cluster failed to join"
        ((failed++))
    fi
done

echo -e "\n=== Join Summary ==="
echo "Successful: $success"
echo "Failed: $failed"
echo "Total: ${#clusters[@]}"
EOF

chmod +x /root/karmada-setup/scripts/join-all-clusters.sh
```

## 4.4 Check Cluster Status

After joining, verify cluster status:

```bash
# List all joined clusters
kubectl karmada get clusters

# Expected output format:
# NAME   VERSION        MODE   READY   AGE
# vn     v1.32.5+k3s1   Push   True    1m
# vn2    v1.32.5+k3s1   Push   True    1m
# us     v1.32.5+k3s1   Push   True    1m
# eu     v1.32.5+k3s1   Push   True    1m
# jp     v1.32.5+k3s1   Push   True    1m
```

## 4.5 Get Detailed Cluster Information

Create a script to show detailed cluster information:

```bash
cat > /root/karmada-setup/scripts/show-cluster-details.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Cluster Details ==="

export KUBECONFIG=/root/karmada-setup/configs/karmada-kubeconfig

# Get all clusters
clusters=$(kubectl get clusters -o jsonpath='{.items[*].metadata.name}')

for cluster in $clusters; do
    echo -e "\n--- Cluster: $cluster ---"
    
    # Get basic info
    kubectl get cluster $cluster -o custom-columns=NAME:.metadata.name,VERSION:.status.kubernetesVersion,MODE:.spec.syncMode,READY:.status.conditions[?(@.type=="Ready")].status,API:.status.apiEndpoint
    
    # Get node count
    node_count=$(kubectl get cluster $cluster -o jsonpath='{.status.nodeSummary.readyNum}')
    total_nodes=$(kubectl get cluster $cluster -o jsonpath='{.status.nodeSummary.totalNum}')
    echo "Nodes: $node_count/$total_nodes ready"
    
    # Get resource capacity
    echo "Resources:"
    kubectl get cluster $cluster -o jsonpath='{range .status.resourceSummary.allocatable}{.resource}: {.quantity}{"\n"}{end}' 2>/dev/null | head -4
done
EOF

chmod +x /root/karmada-setup/scripts/show-cluster-details.sh
/root/karmada-setup/scripts/show-cluster-details.sh
```

## 4.6 Label Clusters

Add labels to clusters for easier management:

```bash
# Label by region
kubectl karmada label cluster vn region=vietnam
kubectl karmada label cluster vn2 region=vietnam
kubectl karmada label cluster us region=americas
kubectl karmada label cluster eu region=europe
kubectl karmada label cluster jp region=asia-pacific

# Label by tier
kubectl karmada label cluster vn tier=production
kubectl karmada label cluster vn2 tier=production
kubectl karmada label cluster us tier=production
kubectl karmada label cluster eu tier=production
kubectl karmada label cluster jp tier=production

# Label special capabilities
kubectl karmada label cluster vn storage=longhorn
```

## 4.7 Verify Labels

Check that labels were applied:

```bash
# Show clusters with labels
kubectl get clusters --show-labels

# Filter by label
echo -e "\n--- Production clusters ---"
kubectl get clusters -l tier=production

echo -e "\n--- Vietnam region clusters ---"
kubectl get clusters -l region=vietnam
```

## 4.8 Check Karmada Agent Status

Verify that Karmada agents are running in each cluster:

```bash
cat > /root/karmada-setup/scripts/check-agents.sh << 'EOF'
#!/bin/bash
echo "=== Checking Karmada Agents in Member Clusters ==="

cd /root/karmada-setup/configs

for config in kubeconfig-*; do
    if [[ -f "$config" && ! "$config" =~ \.original$ ]]; then
        cluster=${config#kubeconfig-}
        echo -e "\n--- $cluster cluster ---"
        
        # Check for karmada-agent
        agent_status=$(kubectl --kubeconfig=$config get deploy -n karmada-system karmada-agent -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        
        if [[ "$agent_status" == "True" ]]; then
            echo "✓ Karmada agent is running"
            kubectl --kubeconfig=$config get pods -n karmada-system -l app=karmada-agent
        else
            echo "✗ Karmada agent not found or not ready"
        fi
    fi
done
EOF

chmod +x /root/karmada-setup/scripts/check-agents.sh
/root/karmada-setup/scripts/check-agents.sh
```

## 4.9 Troubleshooting Failed Joins

If any cluster fails to join:

```bash
# Check specific cluster status
kubectl describe cluster <cluster-name>

# Common issues and solutions:

# 1. Authentication failed
# - Verify kubeconfig is correct
# - Test with: kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-<cluster> get nodes

# 2. Network connectivity
# - Check WireGuard connectivity: ping <cluster-wireguard-ip>
# - Verify port 6443 is open: nc -zv <cluster-wireguard-ip> 6443

# 3. Karmada agent deployment failed
# - Check agent logs in member cluster:
#   kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-<cluster> logs -n karmada-system -l app=karmada-agent

# 4. Re-join a cluster
# First unjoin:
kubectl karmada unjoin <cluster-name>
# Then join again:
kubectl karmada join <cluster-name> --cluster-kubeconfig=/root/karmada-setup/configs/kubeconfig-<cluster> --cluster-context=<cluster>
```

## 4.10 Create Health Check Script

Monitor cluster health continuously:

```bash
cat > /root/karmada-setup/scripts/cluster-health-check.sh << 'EOF'
#!/bin/bash
echo "=== Karmada Cluster Health Check ==="
echo "Time: $(date)"
echo ""

export KUBECONFIG=/root/karmada-setup/configs/karmada-kubeconfig

# Summary
total=$(kubectl get clusters --no-headers | wc -l)
ready=$(kubectl get clusters --no-headers | grep -c "True")
not_ready=$((total - ready))

echo "Total Clusters: $total"
echo "Ready: $ready"
echo "Not Ready: $not_ready"
echo ""

# Detailed status
if [[ $not_ready -gt 0 ]]; then
    echo "--- Clusters with issues ---"
    kubectl get clusters --no-headers | grep -v "True" | while read line; do
        cluster=$(echo $line | awk '{print $1}')
        echo "Cluster: $cluster"
        kubectl describe cluster $cluster | grep -A5 "Conditions:"
        echo ""
    done
fi

# Resource summary
echo "--- Total Resources Across All Clusters ---"
echo "Calculating..."
# This would aggregate resources from all clusters
EOF

chmod +x /root/karmada-setup/scripts/cluster-health-check.sh
```

## 4.11 Save Join Configuration

Document the join configuration for future reference:

```bash
cat > /root/karmada-setup/configs/cluster-join-log.txt << EOF
Karmada Cluster Join Log
========================
Date: $(date)
Karmada Host: United States (us)

Joined Clusters:
$(kubectl karmada get clusters --no-headers | awk '{print "- " $1 " (" $3 " mode, " $4 " ready)"}')

Cluster Namespaces:
$(kubectl get ns | grep karmada-cluster- | awk '{print "- " $1}')

Labels Applied:
- Region: vietnam, americas, europe, asia-pacific
- Tier: production
- Special: storage=longhorn (vn cluster)

Join Commands Used:
$(cat /root/karmada-setup/scripts/join-all-clusters.sh | grep "kubectl karmada join" | sed 's/^/- /')
EOF

echo "Join configuration saved to: /root/karmada-setup/configs/cluster-join-log.txt"
```

## 4.12 Verification Checklist

Before proceeding to Step 5:

- [ ] All 5 clusters joined successfully (vn, vn2, us, eu, jp)
- [ ] All clusters show "Ready" status
- [ ] Clusters are properly labeled by region and tier
- [ ] Karmada agents are running in all member clusters
- [ ] Health check script created and tested

## Quick Summary

```bash
# Quick cluster status
echo "=== Cluster Join Summary ==="
echo "Joined clusters: $(kubectl get clusters --no-headers | wc -l)"
echo "Ready clusters: $(kubectl get clusters --no-headers | grep -c True)"
kubectl get clusters
```

## Next Step

With all clusters successfully joined, proceed to [Step 5: Verify Setup](./step-5-verify-setup.md)