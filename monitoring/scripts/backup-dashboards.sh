#!/bin/bash

# Script to backup Grafana dashboards
# Usage: ./backup-dashboards.sh <cluster-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if cluster name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

CLUSTER=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="dashboard-backups/${CLUSTER}_${TIMESTAMP}"

echo -e "${GREEN}Backing up dashboards from cluster: $CLUSTER${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get all ConfigMaps with grafana_dashboard label
echo -e "${YELLOW}Finding dashboard ConfigMaps...${NC}"
CONFIGMAPS=$(kubectl get configmap -A -l grafana_dashboard=1 -o json)

# Extract and save each dashboard
echo "$CONFIGMAPS" | jq -r '.items[] | "\(.metadata.namespace):\(.metadata.name)"' | while IFS=: read -r namespace name; do
    echo -e "${YELLOW}Backing up $name from namespace $namespace${NC}"

    # Get the ConfigMap
    kubectl get configmap -n "$namespace" "$name" -o yaml > "$BACKUP_DIR/${namespace}_${name}.yaml"

    # Extract just the dashboard JSON
    kubectl get configmap -n "$namespace" "$name" -o json | \
        jq -r '.data | to_entries[] | select(.key | endswith(".json")) | .value' > "$BACKUP_DIR/${namespace}_${name}.json" 2>/dev/null || true
done

# Also backup dashboards from Grafana API if accessible
echo -e "${YELLOW}Attempting to backup from Grafana API...${NC}"
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$GRAFANA_POD" ]; then
    # Get admin password
    ADMIN_PASS=$(kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

    # Port forward in background
    kubectl port-forward -n monitoring "pod/$GRAFANA_POD" 3000:3000 &
    PF_PID=$!
    sleep 5

    # Try to fetch dashboards via API
    curl -s -u "admin:$ADMIN_PASS" http://localhost:3000/api/search | jq -r '.[] | select(.type=="dash-db") | .uid' | while read -r uid; do
        if [ -n "$uid" ]; then
            echo -e "${YELLOW}Backing up dashboard UID: $uid${NC}"
            curl -s -u "admin:$ADMIN_PASS" "http://localhost:3000/api/dashboards/uid/$uid" | \
                jq '.dashboard' > "$BACKUP_DIR/grafana_api_${uid}.json"
        fi
    done 2>/dev/null || true

    # Kill port forward
    kill $PF_PID 2>/dev/null || true
fi

echo -e "${GREEN}Backup completed!${NC}"
echo "Dashboards saved to: $BACKUP_DIR"
echo ""
echo "To restore dashboards to another cluster:"
echo "1. Apply ConfigMap YAMLs: kubectl apply -f $BACKUP_DIR/*.yaml"
echo "2. Or import JSON files via Grafana UI"
