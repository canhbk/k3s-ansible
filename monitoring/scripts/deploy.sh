#!/bin/bash

# Deployment script for kube-prometheus-stack
# Usage: ./deploy.sh <cluster-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if cluster name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    echo "Available clusters: dev, eu, jp, sg, sg2, us, vn, vn2"
    exit 1
fi

CLUSTER=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BASE_DIR="$SCRIPT_DIR/.."
CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER"

# Check if cluster directory exists
if [ ! -d "$CLUSTER_DIR" ]; then
    echo -e "${RED}Error: Cluster directory not found: $CLUSTER_DIR${NC}"
    echo "Please create cluster-specific configuration first"
    exit 1
fi

echo -e "${GREEN}Deploying monitoring stack to cluster: $CLUSTER${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Create namespace
echo -e "${YELLOW}Creating monitoring namespace...${NC}"
kubectl apply -f "$BASE_DIR/base/namespace.yaml"

# Add prometheus-community repo
echo -e "${YELLOW}Adding Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy kube-prometheus-stack
echo -e "${YELLOW}Installing kube-prometheus-stack...${NC}"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values "$BASE_DIR/base/kube-prometheus-stack/values-base.yaml" \
    --values "$CLUSTER_DIR/values.yaml" \
    --timeout 10m \
    --wait

# Apply ingress if exists
if [ -f "$CLUSTER_DIR/ingress.yaml" ]; then
    echo -e "${YELLOW}Applying ingress configuration...${NC}"
    kubectl apply -f "$CLUSTER_DIR/ingress.yaml"
fi

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Get Grafana password
echo -e "${GREEN}Deployment completed!${NC}"
echo ""
echo -e "${YELLOW}Grafana admin password:${NC}"
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo ""
echo ""

# Display access information
echo -e "${GREEN}Access Information:${NC}"
if [ "$CLUSTER" == "dev" ]; then
    echo "Grafana: https://grafana.dev.k3s.canhnv.com"
else
    echo "Grafana: https://grafana.$CLUSTER.k3s.canhnv.com"
fi
echo ""
echo "For Prometheus access (port-forward):"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""
echo "For Alertmanager access (port-forward):"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"