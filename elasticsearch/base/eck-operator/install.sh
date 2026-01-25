#!/bin/bash

# ECK Operator Installation Script
# Usage: ./install.sh <cluster-context>

set -e

CLUSTER=${1:-eu}

echo "Installing ECK Operator on cluster: $CLUSTER"

# Switch context
kubectl config use-context $CLUSTER

# Install ECK CRDs
kubectl create -f https://download.elastic.co/downloads/eck/2.16.1/crds.yaml || true

# Install ECK Operator with RBAC rules
kubectl apply -f https://download.elastic.co/downloads/eck/2.16.1/operator.yaml

# Wait for operator to be ready
echo "Waiting for ECK operator to be ready..."
kubectl -n elastic-system rollout status deployment/elastic-operator

echo "ECK Operator installed successfully!"
kubectl get pods -n elastic-system
