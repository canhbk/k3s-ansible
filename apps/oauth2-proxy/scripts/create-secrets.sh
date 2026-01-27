#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

CLUSTER=$1

echo -e "${GREEN}Creating oauth2-proxy secrets for cluster: $CLUSTER${NC}"
echo ""

kubectl config use-context $CLUSTER
kubectl create namespace oauth2-proxy --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}Please provide OAuth credentials:${NC}"
echo ""

read -p "Enter OAuth Client ID: " CLIENT_ID
if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Error: Client ID is required${NC}"
    exit 1
fi

read -sp "Enter OAuth Client Secret: " CLIENT_SECRET
echo ""
if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}Error: Client Secret is required${NC}"
    exit 1
fi

echo -e "${YELLOW}Generating secure cookie secret...${NC}"
COOKIE_SECRET=$(openssl rand -base64 32 | head -c 32 | base64)

echo -e "${YELLOW}Creating Kubernetes secret...${NC}"
kubectl create secret generic oauth2-proxy-secrets \
    --namespace oauth2-proxy \
    --from-literal=client-id="$CLIENT_ID" \
    --from-literal=client-secret="$CLIENT_SECRET" \
    --from-literal=cookie-secret="$COOKIE_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo -e "${GREEN}Secret created successfully!${NC}"
echo "Deploy with: ./deploy.sh $CLUSTER"
