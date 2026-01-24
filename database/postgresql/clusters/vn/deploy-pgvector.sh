#!/bin/bash
# Deploy PostgreSQL with pgvector on VN cluster
# This script deploys a new PostgreSQL cluster with pgvector extension
# alongside the existing PostgreSQL cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}PostgreSQL with pgvector Deployment for VN Cluster${NC}"
echo "=================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl could not be found. Please install kubectl first.${NC}"
    exit 1
fi

# Switch to VN context
echo -e "${YELLOW}Switching to VN cluster context...${NC}"
kubectl config use-context vn

# Verify we're on the correct cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "vn" ]; then
    echo -e "${RED}Failed to switch to VN context. Current context: $CURRENT_CONTEXT${NC}"
    exit 1
fi

echo -e "${GREEN}Current context: $CURRENT_CONTEXT${NC}"

# Check if namespace exists
if ! kubectl get namespace postgres-db &> /dev/null; then
    echo -e "${YELLOW}Creating namespace postgres-db...${NC}"
    kubectl create namespace postgres-db
else
    echo -e "${GREEN}Namespace postgres-db already exists${NC}"
fi

# Check if CNPG operator is installed
if ! kubectl get pods -n cnpg-system &> /dev/null; then
    echo -e "${RED}CloudNative-PG operator is not installed!${NC}"
    echo "Please install it first using:"
    echo "kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.26/releases/cnpg-1.26.0.yaml"
    exit 1
else
    echo -e "${GREEN}CloudNative-PG operator is installed${NC}"
fi

# Check if secrets file has been updated
if grep -q "<CHANGE_ME_" secrets-pgvector.yaml; then
    echo -e "${RED}ERROR: Please update the passwords in secrets-pgvector.yaml before deploying!${NC}"
    echo "Generate secure passwords with: openssl rand -base64 32"
    exit 1
fi

# Deploy secrets
echo -e "${YELLOW}Applying secrets...${NC}"
kubectl apply -f secrets-pgvector.yaml

# Deploy cluster
echo -e "${YELLOW}Deploying PostgreSQL cluster with pgvector...${NC}"
kubectl apply -f cluster-pgvector.yaml

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready (this may take a few minutes)...${NC}"
kubectl wait --for=condition=Ready cluster/postgresql-pgvector -n postgres-db --timeout=300s

# Check pod status
echo -e "${GREEN}Cluster deployed! Checking pod status:${NC}"
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-pgvector

# Show cluster status
echo -e "${GREEN}Cluster status:${NC}"
kubectl get cluster -n postgres-db postgresql-pgvector

# Deploy LoadBalancer service (optional)
read -p "Do you want to deploy the LoadBalancer service for external access? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying LoadBalancer service...${NC}"
    kubectl apply -f postgres-murror-ai-loadbalancer.yaml
    echo -e "${GREEN}LoadBalancer service deployed${NC}"
    
    # Wait for external IP
    echo -e "${YELLOW}Waiting for external IP assignment...${NC}"
    kubectl get svc postgres-murror-ai-pgvector -n postgres-db
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo
echo "Next steps:"
echo "1. Verify pgvector extension: kubectl exec -it -n postgres-db postgresql-pgvector-1 -- psql -U postgres -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
echo "2. Check service endpoints: kubectl get svc -n postgres-db | grep pgvector"
echo "3. Test connection to murror-ai database with AI user credentials"