#!/bin/bash

# Install cert-manager for SG3 cluster
set -e

echo "Installing cert-manager for SG3 cluster..."

# Switch to SG3 cluster context
kubectl config use-context sg3

# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true \
  --wait

echo "cert-manager installed successfully!"

# Verify installation
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager

echo "SG3 cluster cert-manager installation complete!"
