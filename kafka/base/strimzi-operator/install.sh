#!/bin/bash

# Install Strimzi Kafka Operator
set -e

STRIMZI_VERSION="${STRIMZI_VERSION:-0.50.0}"
NAMESPACE="${NAMESPACE:-kafka}"

echo "Installing Strimzi Kafka Operator v${STRIMZI_VERSION} to namespace ${NAMESPACE}..."

# Switch to US cluster context
kubectl config use-context us

# Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install Strimzi Operator using Helm
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace ${NAMESPACE} \
  --version ${STRIMZI_VERSION} \
  --set watchNamespaces="{${NAMESPACE}}" \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=500m \
  --set resources.limits.memory=512Mi \
  --wait

echo "Strimzi Kafka Operator installed successfully!"

# Verify installation
kubectl get pods -n ${NAMESPACE} -l name=strimzi-cluster-operator

echo "Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n ${NAMESPACE} --timeout=120s

echo "Strimzi Operator is ready!"
