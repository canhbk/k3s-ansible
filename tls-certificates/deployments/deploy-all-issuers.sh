#!/bin/bash

# Deploy all ClusterIssuers to all K3s clusters
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "Deploying ALL ClusterIssuers to all clusters"
echo "======================================"
echo

# Deploy each domain
echo "1. Deploying canhnv.com ClusterIssuer..."
bash "$SCRIPT_DIR/deploy-canhnv-com.sh"

echo
echo "2. Deploying xbuzi.com ClusterIssuer..."
bash "$SCRIPT_DIR/deploy-xbuzi-com.sh"

echo
echo "3. Deploying ambercare-app (murror.app) ClusterIssuer..."
bash "$SCRIPT_DIR/deploy-ambercare-app.sh"

echo
echo "======================================"
echo "All deployments completed!"
echo "======================================"
