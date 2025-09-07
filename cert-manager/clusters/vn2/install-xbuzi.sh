#!/bin/bash

# Install xbuzi.com ClusterIssuer for vn2 cluster
set -e

echo "Installing xbuzi.com ClusterIssuer for vn2 cluster..."

# Switch to vn2 cluster context
kubectl config use-context vn2

# Check if cert-manager namespace exists
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "cert-manager namespace not found. Please install cert-manager first."
    exit 1
fi

# Apply Cloudflare secret
echo "Applying Cloudflare secret..."
kubectl apply -f ../../base/cloudflare-secret.yaml

# Apply xbuzi.com ClusterIssuer
echo "Applying xbuzi.com ClusterIssuer..."
kubectl apply -f ../../base/xbuzi-com-clusterissuer.yaml

# Verify installation
echo "Verifying installation..."
kubectl get clusterissuer xbuzi-com-staging xbuzi-com
kubectl get secret cloudflare-token-secret -n cert-manager

echo "xbuzi.com ClusterIssuer installed successfully on vn2 cluster!"
