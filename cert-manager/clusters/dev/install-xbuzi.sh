#!/bin/bash

# Install xbuzi.com ClusterIssuer for dev cluster
set -e

echo "Installing xbuzi.com ClusterIssuer for dev cluster..."

# Switch to dev cluster context
kubectl config use-context dev

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

echo "xbuzi.com ClusterIssuer installed successfully on dev cluster!"