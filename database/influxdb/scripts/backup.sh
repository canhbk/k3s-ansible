#!/bin/bash

# Backup script for InfluxDB
# Usage: ./backup.sh <cluster-name> [backup-dir]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if cluster name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo "Usage: $0 <cluster-name> [backup-dir]"
    echo "Available clusters: dev, eu, jp, sg, sg2, us, vn, vn2"
    exit 1
fi

CLUSTER=$1
BACKUP_DIR=${2:-"./backups"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/influxdb-$CLUSTER-$TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backing up InfluxDB from cluster: $CLUSTER${NC}"
echo -e "${GREEN}========================================${NC}"

# Switch to the correct context
echo -e "${YELLOW}Switching to kubectl context: $CLUSTER${NC}"
kubectl config use-context $CLUSTER

# Get the InfluxDB pod name
POD_NAME=$(kubectl get pods -n influxdb -l app.kubernetes.io/name=influxdb2 -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Error: No InfluxDB pod found in cluster $CLUSTER${NC}"
    exit 1
fi

echo -e "${YELLOW}Found InfluxDB pod: $POD_NAME${NC}"

# Get admin token
echo -e "${YELLOW}Retrieving admin token...${NC}"
ADMIN_PASSWORD=$(kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d)

# Get organization name from values
if [ "$CLUSTER" == "dev" ]; then
    ORG="k3s-dev"
else
    ORG="k3s-$CLUSTER"
fi

echo -e "${YELLOW}Starting backup for organization: $ORG${NC}"

# Create backup inside the pod
echo -e "${YELLOW}Creating backup inside pod...${NC}"
kubectl exec -n influxdb $POD_NAME -- influx backup /tmp/backup-$TIMESTAMP \
    --host http://localhost:8086 \
    --token $(kubectl exec -n influxdb $POD_NAME -- influx auth list --json | jq -r '.[0].token')

# Copy backup from pod to local
echo -e "${YELLOW}Copying backup to local filesystem...${NC}"
kubectl cp -n influxdb $POD_NAME:/tmp/backup-$TIMESTAMP $BACKUP_PATH

# Clean up backup from pod
echo -e "${YELLOW}Cleaning up temporary files in pod...${NC}"
kubectl exec -n influxdb $POD_NAME -- rm -rf /tmp/backup-$TIMESTAMP

# Create backup metadata
echo -e "${YELLOW}Creating backup metadata...${NC}"
cat > "$BACKUP_PATH/metadata.json" <<EOF
{
    "cluster": "$CLUSTER",
    "timestamp": "$TIMESTAMP",
    "date": "$(date)",
    "organization": "$ORG",
    "influxdb_version": "$(kubectl exec -n influxdb $POD_NAME -- influx version)",
    "pod": "$POD_NAME"
}
EOF

# Compress backup
echo -e "${YELLOW}Compressing backup...${NC}"
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "influxdb-$CLUSTER-$TIMESTAMP"
rm -rf "$BACKUP_PATH"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "${BLUE}Backup Information:${NC}"
echo -e "Location: ${YELLOW}$BACKUP_PATH.tar.gz${NC}"
echo -e "Size: $(du -h $BACKUP_PATH.tar.gz | cut -f1)"
echo ""

echo -e "${YELLOW}To restore this backup:${NC}"
echo "1. Extract: tar -xzf $BACKUP_PATH.tar.gz"
echo "2. Copy to pod: kubectl cp influxdb-$CLUSTER-$TIMESTAMP <pod>:/tmp/"
echo "3. Restore: kubectl exec <pod> -- influx restore /tmp/influxdb-$CLUSTER-$TIMESTAMP"
