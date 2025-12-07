#!/bin/bash
# Script to check available Karmada versions and install the latest
# Run this on vps9

echo "=== Checking Available Karmada Versions ==="
echo ""

# List available versions
echo "Available Karmada chart versions:"
helm search repo karmada-charts/karmada --versions | head -20

# Get the latest version
LATEST_VERSION=$(helm search repo karmada-charts/karmada -o json | jq -r '.[0].version')
echo ""
echo "Latest available version: $LATEST_VERSION"

# Ask to proceed with installation
echo ""
echo "Would you like to install Karmada version $LATEST_VERSION? (y/n)"
read -r response

if [[ "$response" == "y" ]]; then
    echo ""
    echo "Installing Karmada version $LATEST_VERSION..."

    KARMADA_NAMESPACE="karmada-system"
    SETUP_DIR="/root/karmada-setup"

    # Ensure namespace exists
    kubectl create namespace $KARMADA_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Install with the correct version
    helm install karmada karmada-charts/karmada \
      --namespace $KARMADA_NAMESPACE \
      --version $LATEST_VERSION \
      --values $SETUP_DIR/configs/karmada-values.yaml \
      --wait \
      --timeout 10m

    echo ""
    echo "Installation complete. Checking status..."
    kubectl get pods -n $KARMADA_NAMESPACE
else
    echo "Installation cancelled."
fi
