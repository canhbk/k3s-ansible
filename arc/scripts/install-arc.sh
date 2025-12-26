#!/bin/bash
set -e

# Configuration
CLUSTER_CONTEXT="vn2"
CONTROLLER_NAMESPACE="arc-systems"
RUNNER_NAMESPACE="arc-runners"
HELM_VERSION="0.10.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== ARC Installation for VN2 Cluster ==="
echo "Context: ${CLUSTER_CONTEXT}"
echo "Controller Namespace: ${CONTROLLER_NAMESPACE}"
echo "Runner Namespace: ${RUNNER_NAMESPACE}"
echo "Helm Chart Version: ${HELM_VERSION}"
echo ""

# Switch context
echo "Switching to ${CLUSTER_CONTEXT} context..."
kubectl config use-context ${CLUSTER_CONTEXT}

# Verify cluster access
echo "Verifying cluster access..."
kubectl get nodes
echo ""

# Step 1: Create namespaces
echo "Step 1: Creating namespaces..."
kubectl apply -f ${BASE_DIR}/base/namespace.yaml
echo ""

# Step 2: Check for secrets
echo "Step 2: Checking for GitHub App secret..."
if kubectl get secret github-app-secret -n ${RUNNER_NAMESPACE} &>/dev/null; then
    echo "GitHub App secret exists."
else
    echo ""
    echo "ERROR: github-app-secret not found in ${RUNNER_NAMESPACE} namespace!"
    echo ""
    echo "Please create the secret first:"
    echo ""
    echo "  kubectl create secret generic github-app-secret \\"
    echo "    --namespace ${RUNNER_NAMESPACE} \\"
    echo "    --from-literal=github_app_id=<APP_ID> \\"
    echo "    --from-literal=github_app_installation_id=<INSTALLATION_ID> \\"
    echo "    --from-file=github_app_private_key=<PATH_TO_PEM_FILE>"
    echo ""
    echo "To get these values:"
    echo "  1. Create a GitHub App at: https://github.com/organizations/murror/settings/apps/new"
    echo "  2. Set permissions: Repository (Actions: Read, Administration: Read & Write, Metadata: Read)"
    echo "  3. Set permissions: Organization (Self-hosted runners: Read & Write)"
    echo "  4. Install the app on your organization"
    echo "  5. Download the private key (.pem file)"
    echo "  6. Note the App ID and Installation ID"
    echo ""
    exit 1
fi
echo ""

# Step 3: Install ARC Controller
echo "Step 3: Installing ARC Controller..."
helm upgrade --install arc-controller \
  --namespace ${CONTROLLER_NAMESPACE} \
  --values ${BASE_DIR}/clusters/vn2/values-controller.yaml \
  --wait \
  --timeout 5m \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version ${HELM_VERSION}

# Wait for controller to be ready
echo "Waiting for controller to be ready..."
kubectl -n ${CONTROLLER_NAMESPACE} rollout status deployment arc-controller-gha-runner-scale-set-controller --timeout=120s
echo ""

# Step 4: Install Runner Scale Set
echo "Step 4: Installing Runner Scale Set..."
helm upgrade --install vn2-runners \
  --namespace ${RUNNER_NAMESPACE} \
  --values ${BASE_DIR}/clusters/vn2/values-runner-scaleset.yaml \
  --wait \
  --timeout 5m \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version ${HELM_VERSION}

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Verify deployment:"
echo "  kubectl -n ${CONTROLLER_NAMESPACE} get pods"
echo "  kubectl -n ${RUNNER_NAMESPACE} get pods"
echo ""
echo "Check runner registration in GitHub:"
echo "  https://github.com/organizations/murror/settings/actions/runners"
echo ""
echo "To use the runners in your workflows:"
echo "  runs-on: [self-hosted, vn2-runners]"
