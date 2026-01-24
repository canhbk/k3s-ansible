#!/bin/bash

# Install all ClusterIssuers for US cluster
set -e

CLUSTER_NAME="us"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "======================================"
echo "Installing ClusterIssuers for $CLUSTER_NAME cluster"
echo "======================================"

# Switch to cluster context
kubectl config use-context $CLUSTER_NAME

# Check if cert-manager namespace exists
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "ERROR: cert-manager namespace not found. Please install cert-manager first."
    echo "Run: ./install-cert-manager.sh"
    exit 1
fi

# Deploy all secrets
echo
echo "Deploying secrets..."
echo "--------------------"

if [ -f "$BASE_DIR/secrets/canhnv-com-secret.local.yaml" ]; then
    echo "Applying canhnv.com Cloudflare secret..."
    kubectl apply -f "$BASE_DIR/secrets/canhnv-com-secret.local.yaml"
fi

if [ -f "$BASE_DIR/secrets/cloudflare-secret.local.yaml" ]; then
    echo "Applying xbuzi.com Cloudflare secret..."
    kubectl apply -f "$BASE_DIR/secrets/cloudflare-secret.local.yaml"
fi

if [ -f "$BASE_DIR/secrets/murror-cloudflare-secret.yaml" ]; then
    echo "Applying murror.app Cloudflare secret..."
    kubectl apply -f "$BASE_DIR/secrets/murror-cloudflare-secret.yaml"
fi

# Deploy all ClusterIssuers
echo
echo "Deploying ClusterIssuers..."
echo "--------------------"

echo "Applying canhnv.com ClusterIssuer..."
kubectl apply -f "$BASE_DIR/issuers/canhnv-com-clusterissuer.yaml"

echo "Applying xbuzi.com ClusterIssuer..."
kubectl apply -f "$BASE_DIR/issuers/xbuzi-com-clusterissuer.yaml"

echo "Applying ambercare-app ClusterIssuer..."
kubectl apply -f "$BASE_DIR/issuers/ambercare-app-clusterissuer.yaml"

# Verify installation
echo
echo "Verifying installation..."
echo "--------------------"
kubectl get clusterissuer
kubectl get secret -n cert-manager | grep -E "cloudflare|murror"

echo
echo "======================================"
echo "SUCCESS: All ClusterIssuers installed on $CLUSTER_NAME cluster!"
echo "======================================"
