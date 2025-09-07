#!/bin/bash

# Deploy xbuzi.com ClusterIssuer to all K3s clusters
set -e

CLUSTERS=("dev" "eu" "jp" "sg" "sg2" "us" "vn" "vn2")
FAILED_CLUSTERS=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "Deploying xbuzi.com ClusterIssuer to all clusters"
echo "======================================"
echo

# Check if cloudflare token is configured
if grep -q "<YOUR_CLOUDFLARE_API_TOKEN>" "$SCRIPT_DIR/base/cloudflare-secret.yaml"; then
    echo "ERROR: Cloudflare API token not configured!"
    echo "Please edit $SCRIPT_DIR/base/cloudflare-secret.yaml and add your Cloudflare API token"
    exit 1
fi

# Function to check cert-manager installation
check_cert_manager() {
    local cluster=$1
    echo -n "Checking cert-manager in $cluster cluster... "

    kubectl config use-context $cluster &>/dev/null
    if [ $? -ne 0 ]; then
        echo "FAILED - Context not found"
        return 1
    fi

    if kubectl get namespace cert-manager &>/dev/null && kubectl get pods -n cert-manager | grep -q "Running"; then
        echo "OK"
        return 0
    else
        echo "NOT INSTALLED"
        return 1
    fi
}

# Deploy to each cluster
for cluster in "${CLUSTERS[@]}"; do
    echo
    echo "Processing $cluster cluster..."
    echo "------------------------"

    # Check cert-manager first
    if ! check_cert_manager $cluster; then
        echo "WARNING: cert-manager not installed on $cluster cluster. Skipping..."
        FAILED_CLUSTERS+=("$cluster (cert-manager not installed)")
        continue
    fi

    # Run the cluster-specific install script
    if [ -f "$SCRIPT_DIR/clusters/$cluster/install-xbuzi.sh" ]; then
        bash "$SCRIPT_DIR/clusters/$cluster/install-xbuzi.sh"
        if [ $? -ne 0 ]; then
            FAILED_CLUSTERS+=("$cluster (deployment failed)")
        fi
    else
        echo "ERROR: Install script not found for $cluster"
        FAILED_CLUSTERS+=("$cluster (script not found)")
    fi
done

# Summary
echo
echo "======================================"
echo "Deployment Summary"
echo "======================================"

if [ ${#FAILED_CLUSTERS[@]} -eq 0 ]; then
    echo "SUCCESS: xbuzi.com ClusterIssuer deployed to all clusters!"
else
    echo "WARNING: Deployment failed for the following clusters:"
    for failed in "${FAILED_CLUSTERS[@]}"; do
        echo "  - $failed"
    done
    echo
    echo "To install cert-manager on missing clusters, use:"
    echo "  ./clusters/<cluster-name>/install.sh"
fi

echo
echo "To verify deployment on a specific cluster:"
echo "  kubectl config use-context <cluster-name>"
echo "  kubectl get clusterissuer"
echo "  kubectl describe clusterissuer xbuzi-com"
