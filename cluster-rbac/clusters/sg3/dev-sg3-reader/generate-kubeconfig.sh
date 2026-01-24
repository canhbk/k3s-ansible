#!/bin/bash

set -euo pipefail

# Configuration
SA_NAME="dev-sg3-reader"
NAMESPACE="dev-access"
OUTPUT_FILE="$SA_NAME.kubeconfig.yaml"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Generating kubeconfig for $SA_NAME..."

# Verify we're on the correct cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "sg3" ]]; then
  echo -e "${RED}ERROR: Not on sg3 context (current: $CURRENT_CONTEXT)${NC}"
  echo "Run: kubectl config use-context sg3"
  exit 1
fi

# Get cluster information
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

echo "Cluster: $CLUSTER_NAME"
echo "Server: $SERVER"

# Verify namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}ERROR: Namespace '$NAMESPACE' does not exist${NC}"
  echo "Run: kubectl apply -f dev-sg3-reader-secret.yaml"
  exit 1
fi

# Verify ServiceAccount exists
if ! kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}ERROR: ServiceAccount '$SA_NAME' does not exist in namespace '$NAMESPACE'${NC}"
  echo "Run: kubectl apply -f dev-sg3-reader-secret.yaml"
  exit 1
fi

# Get the secret associated with the ServiceAccount
echo "Extracting credentials..."
SECRET_NAME=$(kubectl get sa "$SA_NAME" -n "$NAMESPACE" -o jsonpath="{.secrets[0].name}")

if [ -z "$SECRET_NAME" ]; then
  echo -e "${RED}ERROR: No secret found for ServiceAccount '$SA_NAME'${NC}"
  echo "The ServiceAccount may not have been properly configured."
  exit 1
fi

echo "Using secret: $SECRET_NAME"

# Extract token and CA cert
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.token}" | base64 -d)
CA_CERT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.ca\.crt}")

# Validate token
if [ -z "$TOKEN" ]; then
  echo -e "${RED}ERROR: Token is empty${NC}"
  echo "Wait a few seconds for Kubernetes to populate the secret, then try again."
  exit 1
fi

if [ -z "$CA_CERT" ]; then
  echo -e "${RED}ERROR: CA certificate is empty${NC}"
  exit 1
fi

# Generate the kubeconfig file
cat <<EOF > "$OUTPUT_FILE"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_CERT
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SA_NAME
    namespace: default
  name: ${SA_NAME}-context
current-context: ${SA_NAME}-context
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo -e "${GREEN}✅ Kubeconfig generated successfully: $OUTPUT_FILE${NC}"
echo ""
echo "Test the configuration with:"
echo "  kubectl --kubeconfig=$OUTPUT_FILE get namespaces"
echo "  kubectl --kubeconfig=$OUTPUT_FILE get pods -A"
echo ""

# Verify access
echo "Verifying access..."
if kubectl --kubeconfig="$OUTPUT_FILE" get namespaces &>/dev/null; then
  echo -e "${GREEN}✅ Access verification successful${NC}"
else
  echo -e "${RED}⚠️  Access verification failed${NC}"
  echo "Check RBAC configuration:"
  echo "  kubectl get clusterrole cluster-workload-reader"
  echo "  kubectl get clusterrolebinding dev-sg3-reader-binding"
fi

echo ""
echo -e "${YELLOW}⚠️  Security reminder:${NC}"
echo "  - This kubeconfig contains authentication credentials"
echo "  - Store securely (1Password, Vault, etc.)"
echo "  - Never commit to version control"
echo "  - Rotate credentials periodically"
