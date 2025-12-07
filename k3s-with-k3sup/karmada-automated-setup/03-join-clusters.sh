#!/bin/bash
# Script to join member clusters to Karmada
# Run this on vps9 after transferring kubeconfig files

set -e

echo "=== Karmada Member Cluster Join Script ==="
echo "This script will join production clusters to Karmada federation"
echo ""

# Configuration
SETUP_DIR="/root/karmada-setup"
KARMADA_CONFIG="$SETUP_DIR/configs/karmada-kubeconfig"
CLUSTERS=("vn" "vn2" "us" "eu" "jp")

# Change to setup directory
cd $SETUP_DIR/configs

# Step 1: Verify kubeconfig files
echo "=== Step 1: Verifying Kubeconfig Files ==="
missing_configs=()
for cluster in "${CLUSTERS[@]}"; do
    if [[ -f "kubeconfig-$cluster" ]]; then
        echo "✓ Found kubeconfig-$cluster"
    else
        echo "✗ Missing kubeconfig-$cluster"
        missing_configs+=($cluster)
    fi
done

if [ ${#missing_configs[@]} -ne 0 ]; then
    echo ""
    echo "ERROR: Missing kubeconfig files for: ${missing_configs[*]}"
    echo "Please transfer the kubeconfig files first using:"
    echo "  scp ~/karmada-kubeconfigs/kubeconfig-* root@46.250.232.0:$SETUP_DIR/configs/"
    exit 1
fi

# Step 2: Test connectivity to each cluster
echo ""
echo "=== Step 2: Testing Cluster Connectivity ==="
for cluster in "${CLUSTERS[@]}"; do
    echo -n "Testing $cluster... "
    if kubectl --kubeconfig="kubeconfig-$cluster" get nodes &>/dev/null; then
        node_count=$(kubectl --kubeconfig="kubeconfig-$cluster" get nodes --no-headers | wc -l)
        echo "✓ Connected ($node_count nodes)"
    else
        echo "✗ Failed to connect"
        exit 1
    fi
done

# Step 3: Join clusters to Karmada
echo ""
echo "=== Step 3: Joining Clusters to Karmada ==="
export KUBECONFIG=$KARMADA_CONFIG

for cluster in "${CLUSTERS[@]}"; do
    echo ""
    echo "Joining $cluster cluster..."

    # Check if cluster already joined
    if kubectl karmada get clusters | grep -q "^$cluster "; then
        echo "⚠️  Cluster $cluster already joined, skipping"
        continue
    fi

    # Join the cluster
    kubectl karmada join $cluster \
        --cluster-kubeconfig="$SETUP_DIR/configs/kubeconfig-$cluster" \
        --cluster-context=$cluster \
        --cluster-namespace=karmada-cluster-$cluster

    echo "✓ Successfully joined $cluster"
done

# Step 4: Verify all clusters joined
echo ""
echo "=== Step 4: Verifying Cluster Registration ==="
kubectl karmada get clusters

# Step 5: Label clusters for easier management
echo ""
echo "=== Step 5: Labeling Clusters ==="

# Geographic regions and tiers
declare -A cluster_labels=(
    ["vn"]="region=vietnam tier=production capabilities=storage"
    ["vn2"]="region=vietnam tier=production capabilities=compute"
    ["us"]="region=americas tier=production"
    ["eu"]="region=europe tier=production"
    ["jp"]="region=asia-pacific tier=production"
)

for cluster in "${CLUSTERS[@]}"; do
    echo "Labeling $cluster..."
    labels=${cluster_labels[$cluster]}
    for label in $labels; do
        kubectl karmada label cluster $cluster $label --overwrite
    done
done

# Step 6: Create cluster status report
echo ""
echo "=== Step 6: Cluster Status Report ==="
cat > $SETUP_DIR/configs/cluster-status.txt << 'EOF'
#!/bin/bash
echo "=== Karmada Federation Status ==="
echo "Date: $(date)"
echo ""
echo "Member Clusters:"
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig get clusters -o wide
echo ""
echo "Cluster Details:"
EOF

for cluster in "${CLUSTERS[@]}"; do
    cat >> $SETUP_DIR/configs/cluster-status.txt << EOF
echo ""
echo "--- $cluster ---"
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig describe cluster $cluster | grep -E "(Status:|Version:|Ready:|Labels:)" | head -5
EOF
done

chmod +x $SETUP_DIR/configs/cluster-status.txt
$SETUP_DIR/configs/cluster-status.txt

# Step 7: Create basic propagation policy
echo ""
echo "=== Step 7: Creating Basic Propagation Policy ==="
cat > $SETUP_DIR/policies/basic-propagation.yaml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: basic-multi-cluster
  namespace: default
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      labelSelector:
        matchLabels:
          karmada.io/managed: "true"
  placement:
    clusterAffinity:
      clusterNames:
        - vn
        - vn2
        - us
        - eu
        - jp
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames:
                - vn
            weight: 2
          - targetCluster:
              clusterNames:
                - vn2
            weight: 2
          - targetCluster:
              clusterNames:
                - us
            weight: 1
          - targetCluster:
              clusterNames:
                - eu
            weight: 1
          - targetCluster:
              clusterNames:
                - jp
            weight: 1
EOF

kubectl --kubeconfig=$KARMADA_CONFIG apply -f $SETUP_DIR/policies/basic-propagation.yaml

echo ""
echo "✓ All clusters successfully joined to Karmada federation!"
echo ""
echo "Summary:"
echo "- Host cluster: Singapore (sg)"
echo "- Member clusters: ${CLUSTERS[*]}"
echo "- Propagation policy: basic-multi-cluster (created)"
echo ""
echo "Next steps:"
echo "1. Deploy test workloads with label 'karmada.io/managed=true'"
echo "2. Monitor cluster health with: kubectl karmada get clusters"
echo "3. Check workload distribution with: kubectl karmada get deployments"
