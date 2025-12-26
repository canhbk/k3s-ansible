#!/bin/bash
set -e

CLUSTER_CONTEXT="vn2"
CONTROLLER_NAMESPACE="arc-systems"
RUNNER_NAMESPACE="arc-runners"

echo "=== ARC Verification for VN2 Cluster ==="
echo ""

# Switch context
echo "Switching to ${CLUSTER_CONTEXT} context..."
kubectl config use-context ${CLUSTER_CONTEXT}
echo ""

# Check controller
echo "1. Controller Status:"
echo "   Deployment:"
kubectl -n ${CONTROLLER_NAMESPACE} get deployment -o wide 2>/dev/null || echo "   No deployments found"
echo ""
echo "   Pods:"
kubectl -n ${CONTROLLER_NAMESPACE} get pods -o wide 2>/dev/null || echo "   No pods found"
echo ""

# Check runner scale set
echo "2. Runner Scale Set Status:"
kubectl -n ${RUNNER_NAMESPACE} get autoscalingrunnerset 2>/dev/null || echo "   No runner scale sets found"
echo ""

# Check listener
echo "3. Listener Status:"
kubectl -n ${RUNNER_NAMESPACE} get pods -l app.kubernetes.io/component=runner-scale-set-listener -o wide 2>/dev/null || echo "   No listener pods found"
echo ""

# Check runner pods (if any are active)
echo "4. Active Runner Pods:"
kubectl -n ${RUNNER_NAMESPACE} get pods -l app.kubernetes.io/component=runner -o wide 2>/dev/null || echo "   No active runner pods (normal when no jobs running)"
echo ""

# Check for errors in controller logs
echo "5. Controller Logs (last 10 lines):"
CONTROLLER_POD=$(kubectl -n ${CONTROLLER_NAMESPACE} get pods -l app.kubernetes.io/name=gha-runner-scale-set-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "${CONTROLLER_POD}" ]; then
    kubectl -n ${CONTROLLER_NAMESPACE} logs ${CONTROLLER_POD} --tail=10 2>/dev/null || echo "   Failed to get logs"
else
    echo "   Controller pod not found"
fi
echo ""

# Check for recent events
echo "6. Recent Events in ${CONTROLLER_NAMESPACE}:"
kubectl -n ${CONTROLLER_NAMESPACE} get events --sort-by='.lastTimestamp' --field-selector type!=Normal 2>/dev/null | tail -5 || echo "   No warning/error events"
echo ""

echo "7. Recent Events in ${RUNNER_NAMESPACE}:"
kubectl -n ${RUNNER_NAMESPACE} get events --sort-by='.lastTimestamp' --field-selector type!=Normal 2>/dev/null | tail -5 || echo "   No warning/error events"
echo ""

echo "=== Verification Complete ==="
echo ""
echo "Check GitHub Organization Runners:"
echo "  https://github.com/organizations/murror/settings/actions/runners"
echo ""
echo "Look for: vn2-runners"
echo ""
echo "Test workflow trigger:"
echo "  The runners should appear when a workflow using 'runs-on: [self-hosted, vn2-runners]' is triggered"
