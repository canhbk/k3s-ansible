#!/bin/bash
# Script to export kubeconfig files for production member clusters
# Run this on your local machine

set -e

echo "=== Karmada Kubeconfig Export Script ==="
echo "This script will export kubeconfig files for production clusters only"
echo "Excluding: dev and sg2 clusters (not managed by Karmada)"
echo ""

# Create directory for kubeconfigs
EXPORT_DIR="$HOME/karmada-kubeconfigs"
mkdir -p "$EXPORT_DIR"

# List of production clusters to export (excluding sg as host, dev, and sg2)
CLUSTERS=("vn" "vn2" "us" "eu" "jp")

echo "Checking available contexts..."
kubectl config get-contexts

echo ""
echo "Exporting kubeconfig files to: $EXPORT_DIR"
echo ""

# Export each cluster's kubeconfig
for cluster in "${CLUSTERS[@]}"; do
    echo -n "Exporting $cluster... "
    if kubectl config get-contexts -o name | grep -q "^${cluster}$"; then
        kubectl config view --minify --flatten --context="$cluster" > "$EXPORT_DIR/kubeconfig-$cluster"
        echo "✓ Done"
    else
        echo "✗ Context not found, skipping"
    fi
done

echo ""
echo "=== Export Summary ==="
ls -la "$EXPORT_DIR"/kubeconfig-* 2>/dev/null || echo "No kubeconfig files found"

echo ""
echo "Next steps:"
echo "1. Transfer these files to Singapore cluster (vps9):"
echo "   scp $EXPORT_DIR/kubeconfig-* root@46.250.232.0:/root/karmada-setup/configs/"
echo ""
echo "2. Then SSH to vps9 and run the setup script:"
echo "   ssh root@46.250.232.0"