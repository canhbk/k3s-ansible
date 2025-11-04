#!/bin/bash
#
# Generate kubeconfig for developers with namespace-restricted read-only access
# Updated: 2025-11-04 (Post vps7 node removal)
#
# This script generates a kubeconfig file for the mur-developers ServiceAccount
# that has read-only access to specific namespaces via namespace-scoped RoleBindings.
#
# Target namespaces:
# - mu-43, mu-66, mu-69, mu-70, mu-81
# - nsp-alpha-murror, nsp-alpha-murror-ai
#

set -euo pipefail

SA_NAME="mur-developers"
NAMESPACE="dev-access"
CLUSTER_NAME="dev"
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
OUTPUT_FILE="mur-developers.kubeconfig.yaml"

# Target namespaces for validation
TARGET_NAMESPACES=(
    "mu-43"
    "mu-66"
    "mu-69"
    "mu-70"
    "mu-81"
    "nsp-alpha-murror"
    "nsp-alpha-murror-ai"
)

echo "Generating kubeconfig for $SA_NAME..."
echo "Cluster: $CLUSTER_NAME"
echo "API Server: $SERVER"
echo ""

# Get the secret name (using the explicitly created secret)
SECRET_NAME="mur-developers-token"

# Verify the secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Error: Secret $SECRET_NAME not found in namespace $NAMESPACE"
    echo "Please ensure you have applied mur-developers-secret.yaml first"
    exit 1
fi

# Extract token and CA cert
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.token}" | base64 -d)
CA_CERT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.ca\.crt}")

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
    namespace: mu-43
  name: ${SA_NAME}-context
current-context: ${SA_NAME}-context
preferences: {}
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo "✅ Kubeconfig generated: $OUTPUT_FILE"
echo ""
echo "📌 Access Control:"
echo "   - Type: Namespace-restricted read-only access"
echo "   - Permitted namespaces:"
for ns in "${TARGET_NAMESPACES[@]}"; do
    echo "     • $ns"
done
echo ""
echo "📌 Usage:"
echo "   export KUBECONFIG=\$PWD/$OUTPUT_FILE"
echo "   kubectl get pods -n mu-43"
echo "   kubectl get pods -n nsp-alpha-murror"
echo ""
echo "🔍 Verifying access..."
KUBECONFIG="$OUTPUT_FILE" kubectl auth can-i get pods -n mu-43 && echo "✅ Access to mu-43: OK" || echo "❌ Access to mu-43: DENIED"
KUBECONFIG="$OUTPUT_FILE" kubectl auth can-i get pods -n default && echo "⚠️  Access to default: GRANTED (should be denied)" || echo "✅ Access to default: DENIED (correct)"