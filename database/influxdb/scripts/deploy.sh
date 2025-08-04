#!/bin/bash

# Deployment script for InfluxDB
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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying InfluxDB to cluster: $CLUSTER${NC}"
echo -e "${GREEN}========================================${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Create namespace
echo -e "${YELLOW}Creating influxdb namespace...${NC}"
kubectl apply -f "$BASE_DIR/base/namespace.yaml"

# Create admin secret if exists
if [ -f "$CLUSTER_DIR/admin-secret.yaml" ]; then
    echo -e "${YELLOW}Creating admin credentials...${NC}"
    kubectl apply -f "$CLUSTER_DIR/admin-secret.yaml"
else
    echo -e "${RED}Warning: No admin-secret.yaml found for cluster $CLUSTER${NC}"
    echo -e "${YELLOW}Using default secret template...${NC}"
    kubectl apply -f "$BASE_DIR/base/secrets/admin-secret.yaml"
fi

# Add influxdata Helm repository
echo -e "${YELLOW}Adding Helm repository...${NC}"
helm repo add influxdata https://helm.influxdata.com/
helm repo update

# Deploy InfluxDB using Helm
echo -e "${YELLOW}Installing InfluxDB...${NC}"
helm upgrade --install influxdb influxdata/influxdb2 \
    --namespace influxdb \
    --values "$BASE_DIR/base/influxdb/values-base.yaml" \
    --values "$CLUSTER_DIR/values.yaml" \
    --set-string adminUser.password="$(kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d)" \
    --timeout 10m \
    --wait

# Apply ingress if exists
if [ -f "$CLUSTER_DIR/ingress.yaml" ]; then
    echo -e "${YELLOW}Applying ingress configuration...${NC}"
    kubectl apply -f "$CLUSTER_DIR/ingress.yaml"
fi

# Wait for pod to be ready
echo -e "${YELLOW}Waiting for InfluxDB pod to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=influxdb2 -n influxdb --timeout=300s

# Get pod status
echo -e "${BLUE}InfluxDB Pod Status:${NC}"
kubectl get pods -n influxdb -l app.kubernetes.io/name=influxdb2

# Get service info
echo -e "${BLUE}InfluxDB Service:${NC}"
kubectl get svc -n influxdb

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"

# Display access information
echo -e "${YELLOW}Access Information:${NC}"
echo -e "Admin Username: admin"
echo -e "Admin Password: $(kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d)"
echo ""

if [ "$CLUSTER" == "dev" ]; then
    echo -e "Web UI: ${BLUE}https://influxdb.dev.k3s.canhnv.com${NC}"
else
    echo -e "Web UI: ${BLUE}https://influxdb.$CLUSTER.k3s.canhnv.com${NC}"
fi

echo ""
echo -e "${YELLOW}CLI Access (port-forward):${NC}"
echo "kubectl port-forward -n influxdb svc/influxdb 8086:8086"
echo ""
echo -e "${YELLOW}Connection String for Applications:${NC}"
echo "http://influxdb.influxdb.svc.cluster.local:8086"
echo ""

# Create initial token if needed
echo -e "${YELLOW}To create an API token:${NC}"
echo "1. Access the web UI"
echo "2. Go to Data > API Tokens"
echo "3. Generate a new token with required permissions"
echo ""
echo -e "Or use CLI after port-forward:"
echo "influx auth create --org k3s-$CLUSTER --all-access"
