#!/bin/bash

# Deployment script for Kong Ingress Controller
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
    echo "Available clusters: dev, eu, jp, sg, sg2, sg3, us, vn, vn2"
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

echo -e "${GREEN}Deploying Kong Ingress Controller to cluster: $CLUSTER${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Create namespace
echo -e "${YELLOW}Creating kong namespace...${NC}"
kubectl apply -f "$BASE_DIR/base/namespace.yaml"

# Install Gateway API CRDs (required for KIC)
echo -e "${YELLOW}Installing Gateway API CRDs...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml || true

# Add Kong Helm repo
echo -e "${YELLOW}Adding Kong Helm repository...${NC}"
helm repo add kong https://charts.konghq.com
helm repo update

# Deploy Kong Ingress Controller
echo -e "${YELLOW}Installing Kong Ingress Controller...${NC}"
helm upgrade --install kong kong/kong \
    --namespace kong \
    --values "$BASE_DIR/base/values-base.yaml" \
    --values "$CLUSTER_DIR/values.yaml" \
    --timeout 10m \
    --wait

# Apply Prometheus plugin configuration
echo -e "${YELLOW}Applying Prometheus plugin configuration...${NC}"
kubectl apply -f "$CLUSTER_DIR/prometheus-plugin.yaml"

# Apply ServiceMonitor
echo -e "${YELLOW}Applying ServiceMonitor for Prometheus...${NC}"
kubectl apply -f "$CLUSTER_DIR/servicemonitor.yaml"

# Apply Prometheus alerts
echo -e "${YELLOW}Applying Prometheus alert rules...${NC}"
kubectl apply -f "$CLUSTER_DIR/prometheus-alerts.yaml"

# Apply ingress configuration
if [ -f "$CLUSTER_DIR/ingress.yaml" ]; then
    echo -e "${YELLOW}Applying ingress configuration...${NC}"
    kubectl apply -f "$CLUSTER_DIR/ingress.yaml"
fi

# Apply Grafana dashboard
MONITORING_DIR="$SCRIPT_DIR/../../monitoring/clusters/$CLUSTER"
if [ -f "$MONITORING_DIR/kong-dashboard-configmap.yaml" ]; then
    echo -e "${YELLOW}Applying Grafana dashboard...${NC}"
    kubectl apply -f "$MONITORING_DIR/kong-dashboard-configmap.yaml"
fi

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for Kong pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n kong --timeout=300s

# Get Kong proxy service info
echo -e "${GREEN}Deployment completed!${NC}"
echo ""
echo -e "${GREEN}=== Kong Deployment Information ===${NC}"
echo ""

# Get service details
echo -e "${YELLOW}Kong Services:${NC}"
kubectl get svc -n kong

echo ""
echo -e "${YELLOW}Kong Pods:${NC}"
kubectl get pods -n kong

echo ""
echo -e "${GREEN}Access Information:${NC}"
echo "Kong Proxy: https://kong.$CLUSTER.canhnv.com"
echo "Kong Admin API: kubectl port-forward -n kong svc/kong-kong-admin 8001:8001"
echo ""
echo "Grafana Dashboard: https://grafana.$CLUSTER.k3s.canhnv.com"
echo "(Import dashboard: Kong API Gateway - SG3)"
echo ""
echo "Prometheus Metrics: kubectl port-forward -n kong svc/kong-kong-status 8100:8100"
echo "Then access: http://localhost:8100/metrics"
echo ""
echo -e "${GREEN}Verification Commands:${NC}"
echo "# Check Kong health"
echo "kubectl exec -it -n kong deploy/kong-kong -- kong health"
echo ""
echo "# Check Prometheus targets"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "# Then visit: http://localhost:9090/targets (search for kong)"
