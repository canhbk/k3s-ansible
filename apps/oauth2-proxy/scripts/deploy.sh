#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    echo "Available clusters: dev, eu, jp, sg, sg2, sg3, us, vn"
    exit 1
fi

CLUSTER=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BASE_DIR="$SCRIPT_DIR/.."
CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER"

if [ ! -d "$CLUSTER_DIR" ]; then
    echo -e "${RED}Error: Cluster directory not found: $CLUSTER_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}Deploying oauth2-proxy to cluster: $CLUSTER${NC}"

echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

echo -e "${YELLOW}Creating oauth2-proxy namespace...${NC}"
kubectl apply -f "$BASE_DIR/base/namespace.yaml"

echo -e "${YELLOW}Checking for oauth2-proxy secrets...${NC}"
if ! kubectl get secret oauth2-proxy-secrets -n oauth2-proxy &> /dev/null; then
    echo -e "${RED}Error: oauth2-proxy-secrets not found${NC}"
    echo "Please create secrets first using: ./create-secrets.sh $CLUSTER"
    exit 1
fi

echo -e "${YELLOW}Adding oauth2-proxy Helm repository...${NC}"
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update

echo -e "${YELLOW}Installing oauth2-proxy...${NC}"
helm upgrade --install oauth2-proxy oauth2-proxy/oauth2-proxy \
    --namespace oauth2-proxy \
    --values "$BASE_DIR/base/values-base.yaml" \
    --values "$CLUSTER_DIR/values.yaml" \
    --timeout 5m \
    --wait

if [ -f "$CLUSTER_DIR/ingress.yaml" ]; then
    echo -e "${YELLOW}Applying ingress configuration...${NC}"
    kubectl apply -f "$CLUSTER_DIR/ingress.yaml"
fi

if [ -f "$CLUSTER_DIR/middleware-forwardauth.yaml" ]; then
    echo -e "${YELLOW}Applying ForwardAuth middleware...${NC}"
    kubectl apply -f "$CLUSTER_DIR/middleware-forwardauth.yaml"
fi

if [ -f "$CLUSTER_DIR/servicemonitor.yaml" ]; then
    echo -e "${YELLOW}Applying ServiceMonitor...${NC}"
    kubectl apply -f "$CLUSTER_DIR/servicemonitor.yaml"
fi

echo -e "${YELLOW}Waiting for oauth2-proxy pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=oauth2-proxy -n oauth2-proxy --timeout=180s

echo -e "${GREEN}Deployment completed!${NC}"
echo ""
echo -e "${GREEN}=== oauth2-proxy Deployment Information ===${NC}"
echo ""
kubectl get pods -n oauth2-proxy
echo ""
kubectl get svc -n oauth2-proxy
echo ""
kubectl get ingress -n oauth2-proxy
echo ""
echo -e "${GREEN}Access: https://oauth2-proxy.$CLUSTER.canhnv.com${NC}"
echo ""
echo -e "${GREEN}Protect services with:${NC}"
echo "  traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd"
