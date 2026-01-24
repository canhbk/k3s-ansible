#!/bin/bash

set -euo pipefail

SA_NAME="dev-logger"
NAMESPACE="dev-access"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
OUTPUT_FILE="$SA_NAME.kubeconfig.yaml"

# Get the secret associated with the ServiceAccount
SECRET_NAME=$(kubectl get sa "$SA_NAME" -n "$NAMESPACE" -o jsonpath="{.secrets[0].name}")

# Extract token and CA cert
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.token}" | base64 -d)
CA_CERT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.ca\.crt}")

# Generate the kubeconfig file
cat <<EOF > "$OUTPUT_FILE"
apiVersion: v1
kind: Config
clusters:
- cluster:
    name: $CLUSTER_NAME
    server: $SERVER
    certificate-authority-data: $CA_CERT
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SA_NAME
  name: ${SA_NAME}-context
current-context: ${SA_NAME}-context
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo "✅ kubeconfig generated: $OUTPUT_FILE"
