#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if cluster name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    echo "Example: $0 sg3"
    exit 1
fi

CLUSTER=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BASE_DIR="$SCRIPT_DIR/.."
CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER"

# Verify cluster directory exists
if [ ! -d "$CLUSTER_DIR" ]; then
    echo -e "${RED}Error: Cluster directory not found: $CLUSTER_DIR${NC}"
    exit 1
fi

# Verify required files exist
if [ ! -f "$BASE_DIR/base/loki/values-base.yaml" ]; then
    echo -e "${RED}Error: Base values file not found: $BASE_DIR/base/loki/values-base.yaml${NC}"
    exit 1
fi

if [ ! -f "$CLUSTER_DIR/loki-values.yaml" ]; then
    echo -e "${RED}Error: Cluster values file not found: $CLUSTER_DIR/loki-values.yaml${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Loki to cluster: $CLUSTER${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Switch kubectl context
echo -e "${YELLOW}1. Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Verify cluster connection
echo -e "${YELLOW}2. Verifying cluster connection...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to cluster $CLUSTER${NC}"
    exit 1
fi
echo -e "${GREEN}   ✓ Connected to cluster${NC}"
echo ""

# Verify monitoring namespace exists
echo -e "${YELLOW}3. Checking monitoring namespace...${NC}"
if ! kubectl get namespace monitoring > /dev/null 2>&1; then
    echo -e "${RED}Error: monitoring namespace does not exist${NC}"
    echo "Create it with: kubectl create namespace monitoring"
    exit 1
fi
echo -e "${GREEN}   ✓ Namespace exists${NC}"
echo ""

# Add Grafana Helm repository
echo -e "${YELLOW}4. Adding Grafana Helm repository...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
echo -e "${GREEN}   ✓ Helm repository updated${NC}"
echo ""

# Deploy Loki via Helm
echo -e "${YELLOW}5. Installing Loki via Helm...${NC}"
echo "   This may take several minutes..."
helm upgrade --install loki grafana/loki \
    --namespace monitoring \
    --values "$BASE_DIR/base/loki/values-base.yaml" \
    --values "$CLUSTER_DIR/loki-values.yaml" \
    --timeout 10m \
    --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✓ Loki installed successfully${NC}"
else
    echo -e "${RED}   ✗ Loki installation failed${NC}"
    exit 1
fi
echo ""

# Apply ingress
if [ -f "$CLUSTER_DIR/loki-ingress.yaml" ]; then
    echo -e "${YELLOW}6. Applying Loki ingress...${NC}"
    kubectl apply -f "$CLUSTER_DIR/loki-ingress.yaml"
    echo -e "${GREEN}   ✓ Ingress applied${NC}"
else
    echo -e "${YELLOW}6. Skipping ingress (file not found)${NC}"
fi
echo ""

# Apply Grafana datasource
if [ -f "$CLUSTER_DIR/loki-datasource.yaml" ]; then
    echo -e "${YELLOW}7. Applying Grafana datasource...${NC}"
    kubectl apply -f "$CLUSTER_DIR/loki-datasource.yaml"
    echo -e "${GREEN}   ✓ Grafana datasource applied${NC}"
else
    echo -e "${YELLOW}7. Skipping datasource (file not found)${NC}"
fi
echo ""

# Apply ServiceMonitor
if [ -f "$CLUSTER_DIR/loki-servicemonitor.yaml" ]; then
    echo -e "${YELLOW}8. Applying Prometheus ServiceMonitor...${NC}"
    kubectl apply -f "$CLUSTER_DIR/loki-servicemonitor.yaml"
    echo -e "${GREEN}   ✓ ServiceMonitor applied${NC}"
else
    echo -e "${YELLOW}8. Skipping ServiceMonitor (file not found)${NC}"
fi
echo ""

# Apply alert rules
if [ -f "$CLUSTER_DIR/loki-alerts.yaml" ]; then
    echo -e "${YELLOW}9. Applying Loki alert rules...${NC}"
    kubectl apply -f "$CLUSTER_DIR/loki-alerts.yaml"
    echo -e "${GREEN}   ✓ Alert rules applied${NC}"
else
    echo -e "${YELLOW}9. Skipping alert rules (file not found)${NC}"
fi
echo ""

# Wait for pods to be ready
echo -e "${YELLOW}10. Waiting for Loki pods to be ready...${NC}"
echo "    This may take a few minutes..."

if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=600s > /dev/null 2>&1; then
    echo -e "${GREEN}    ✓ All Loki pods are ready${NC}"
else
    echo -e "${RED}    ✗ Some pods are not ready yet. Check with: kubectl get pods -n monitoring -l app.kubernetes.io/name=loki${NC}"
fi
echo ""

# Display deployment status
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Loki Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Pods:${NC}"
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
echo ""

echo -e "${YELLOW}Services:${NC}"
kubectl get svc -n monitoring -l app.kubernetes.io/name=loki
echo ""

echo -e "${YELLOW}PVCs:${NC}"
kubectl get pvc -n monitoring | grep loki || echo "No Loki PVCs found"
echo ""

echo -e "${YELLOW}Ingress:${NC}"
kubectl get ingress -n monitoring | grep loki || echo "No Loki ingress found"
echo ""

echo -e "${YELLOW}Certificate:${NC}"
kubectl get certificate -n monitoring | grep loki || echo "No Loki certificate found"
echo ""

# Access information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access Information${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Loki Gateway:${NC} https://loki.$CLUSTER.k3s.canhnv.com"
echo -e "${YELLOW}Grafana:${NC} https://grafana.$CLUSTER.k3s.canhnv.com"
echo ""

# Verification commands
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification Commands${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Check Loki pods:"
echo "  kubectl get pods -n monitoring -l app.kubernetes.io/name=loki"
echo ""
echo "Check Loki logs (write component):"
echo "  kubectl logs -n monitoring -l app.kubernetes.io/component=write --tail=50"
echo ""
echo "Check Promtail logs:"
echo "  kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50"
echo ""
echo "Test Loki API:"
echo "  kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \\"
echo "    curl http://loki-gateway.monitoring.svc.cluster.local/ready"
echo ""
echo "Query logs:"
echo "  kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \\"
echo "    curl -G http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/query \\"
echo "    --data-urlencode 'query={namespace=\"monitoring\"}' \\"
echo "    --data-urlencode 'limit=10'"
echo ""
echo "Port-forward to Prometheus to check targets:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  # Then visit http://localhost:9090/targets and search for 'loki'"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
