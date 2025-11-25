#!/bin/bash

# Deploy ambercare-app (murror.app) ClusterIssuer to all K3s clusters
set -e

CLUSTERS=("dev" "eu" "jp" "sg" "sg2" "sg3" "us" "vn" "vn2")
FAILED_CLUSTERS=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "Deploying ambercare-app ClusterIssuer to all clusters"
echo "======================================"
echo

# Check if secret exists
if ! [ -f "$BASE_DIR/secrets/murror-cloudflare-secret.yaml" ]; then
    echo "ERROR: murror-cloudflare-secret.yaml not found!"
    echo "Please ensure $BASE_DIR/secrets/murror-cloudflare-secret.yaml exists"
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

    # Deploy secret and ClusterIssuer
    echo "Applying murror Cloudflare secret..."
    kubectl apply -f "$BASE_DIR/secrets/murror-cloudflare-secret.yaml"

    echo "Applying ambercare-app ClusterIssuer..."
    kubectl apply -f "$BASE_DIR/issuers/ambercare-app-clusterissuer.yaml"

    if [ $? -eq 0 ]; then
        echo "SUCCESS: ambercare-app ClusterIssuer deployed to $cluster"
    else
        FAILED_CLUSTERS+=("$cluster (deployment failed)")
    fi
done

# Summary
echo
echo "======================================"
echo "Deployment Summary"
echo "======================================"

if [ ${#FAILED_CLUSTERS[@]} -eq 0 ]; then
    echo "SUCCESS: ambercare-app ClusterIssuer deployed to all clusters!"
else
    echo "WARNING: Deployment failed for the following clusters:"
    for failed in "${FAILED_CLUSTERS[@]}"; do
        echo "  - $failed"
    done
fi

echo
echo "To verify deployment on a specific cluster:"
echo "  kubectl config use-context <cluster-name>"
echo "  kubectl get clusterissuer"
echo "  kubectl describe clusterissuer ambercare-app"
