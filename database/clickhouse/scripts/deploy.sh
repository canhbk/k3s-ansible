#!/bin/bash

# Deployment script for ClickHouse on K3s
# Usage: ./deploy.sh <cluster-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if cluster name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    echo "Available clusters: sg3, us, vn"
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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying ClickHouse to cluster: $CLUSTER${NC}"
echo -e "${GREEN}========================================${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context "$CLUSTER"

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Step 1: Create namespace
echo -e "${YELLOW}[1/6] Creating clickhouse namespace...${NC}"
kubectl apply -f "$BASE_DIR/base/namespace.yaml"

# Step 2: Apply secrets
if [ -f "$CLUSTER_DIR/secrets.local.yaml" ]; then
    echo -e "${YELLOW}[2/6] Applying secrets from secrets.local.yaml...${NC}"
    kubectl apply -f "$CLUSTER_DIR/secrets.local.yaml"
else
    echo -e "${RED}Error: secrets.local.yaml not found in $CLUSTER_DIR${NC}"
    echo "Copy secrets.yaml to secrets.local.yaml and fill in the actual values"
    echo "  cp $CLUSTER_DIR/secrets.yaml $CLUSTER_DIR/secrets.local.yaml"
    echo "  # Edit secrets.local.yaml with actual passwords"
    echo "  # Generate SHA256: echo -n 'your-password' | sha256sum"
    exit 1
fi

# Step 3: Apply StatefulSet (ConfigMap + StatefulSet + Services)
echo -e "${YELLOW}[3/6] Applying ClickHouse StatefulSet...${NC}"
kubectl apply -f "$CLUSTER_DIR/statefulset.yaml"

# Step 4: Apply Ingress
echo -e "${YELLOW}[4/6] Applying Ingress configuration...${NC}"
kubectl apply -f "$CLUSTER_DIR/ingress.yaml"

# Step 5: Apply ServiceMonitor
echo -e "${YELLOW}[5/6] Applying ServiceMonitor...${NC}"
kubectl apply -f "$CLUSTER_DIR/servicemonitor.yaml"

# Step 6: Apply Prometheus alerts
echo -e "${YELLOW}[6/6] Applying Prometheus alerting rules...${NC}"
kubectl apply -f "$CLUSTER_DIR/prometheus-alerts.yaml"

# Wait for pod to be ready
echo -e "${YELLOW}Waiting for ClickHouse pod to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=clickhouse \
    -n clickhouse --timeout=300s

# Get pod status
echo -e "${BLUE}ClickHouse Pod Status:${NC}"
kubectl get pods -n clickhouse -l app.kubernetes.io/name=clickhouse -o wide

# Get service info
echo -e "${BLUE}ClickHouse Services:${NC}"
kubectl get svc -n clickhouse

# Health check
echo -e "${YELLOW}Running health check...${NC}"
kubectl exec -n clickhouse clickhouse-0 -- wget -qO- http://localhost:8123/ping
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"

# Display access information
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo -e "Namespace:    clickhouse"
echo -e "StatefulSet:  clickhouse"
echo -e "Pod:          clickhouse-0"
echo ""
echo -e "${YELLOW}External Access:${NC}"
echo -e "HTTP API:     ${BLUE}https://clickhouse.$CLUSTER.k3s.canhnv.com${NC}"
echo -e "Play UI:      ${BLUE}https://clickhouse.$CLUSTER.k3s.canhnv.com/play${NC}"
echo ""
echo -e "${YELLOW}Internal Access (from within cluster):${NC}"
echo -e "HTTP:         http://clickhouse.clickhouse.svc.cluster.local:8123"
echo -e "Native TCP:   clickhouse.clickhouse.svc.cluster.local:9000"
echo -e "Metrics:      http://clickhouse.clickhouse.svc.cluster.local:9363/metrics"
echo ""
echo -e "${YELLOW}Port Forwarding:${NC}"
echo "kubectl --context $CLUSTER port-forward -n clickhouse svc/clickhouse 8123:8123"
echo "kubectl --context $CLUSTER port-forward -n clickhouse svc/clickhouse 9000:9000"
echo ""
echo -e "${YELLOW}Quick Test:${NC}"
echo "curl 'https://clickhouse.$CLUSTER.k3s.canhnv.com/?user=admin&password=<pw>' --data 'SELECT version()'"
echo ""
echo -e "${YELLOW}Create Initial Databases:${NC}"
echo "curl 'https://clickhouse.$CLUSTER.k3s.canhnv.com/?user=admin&password=<pw>' --data 'CREATE DATABASE analytics'"
echo "curl 'https://clickhouse.$CLUSTER.k3s.canhnv.com/?user=admin&password=<pw>' --data 'CREATE DATABASE events'"
