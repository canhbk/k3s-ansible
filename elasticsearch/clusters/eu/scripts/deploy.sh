#!/bin/bash

# Elasticsearch Deployment Script for EU Cluster
# Usage: ./deploy.sh [--with-kibana]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_DIR="$SCRIPT_DIR/.."
BASE_DIR="$CLUSTER_DIR/../.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

WITH_KIBANA=false
if [ "$1" == "--with-kibana" ]; then
    WITH_KIBANA=true
fi

echo -e "${GREEN}Deploying Elasticsearch to EU cluster${NC}"

# Switch context
echo -e "${YELLOW}Switching to kubectl context: eu${NC}"
kubectl config use-context eu

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Check if ECK operator is installed
echo -e "${YELLOW}Checking ECK operator...${NC}"
if ! kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co > /dev/null 2>&1; then
    echo -e "${YELLOW}ECK operator not found. Installing...${NC}"
    $BASE_DIR/base/eck-operator/install.sh eu
fi

# Create namespace
echo -e "${YELLOW}Creating elasticsearch namespace...${NC}"
kubectl apply -f $BASE_DIR/base/namespace.yaml

# Deploy Elasticsearch cluster
echo -e "${YELLOW}Deploying Elasticsearch cluster...${NC}"
kubectl apply -f $CLUSTER_DIR/elasticsearch-cluster.yaml

# Wait for Elasticsearch to be ready
echo -e "${YELLOW}Waiting for Elasticsearch to be ready (this may take several minutes)...${NC}"
kubectl wait --for=condition=Ready elasticsearch/elasticsearch-eu -n elasticsearch --timeout=600s

# Get Elasticsearch password
echo -e "${GREEN}Elasticsearch deployed successfully!${NC}"
ES_PASSWORD=$(kubectl get secret elasticsearch-eu-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d)
echo ""
echo -e "${YELLOW}Elasticsearch password:${NC} $ES_PASSWORD"
echo ""

# Update exporter credentials
echo -e "${YELLOW}Updating elasticsearch exporter credentials...${NC}"
kubectl create secret generic elasticsearch-exporter-credentials \
    --from-literal=ES_URI="https://elastic:${ES_PASSWORD}@elasticsearch-eu-es-http:9200" \
    -n elasticsearch \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy exporter
echo -e "${YELLOW}Deploying Elasticsearch exporter for Prometheus metrics...${NC}"
kubectl apply -f $CLUSTER_DIR/elasticsearch-exporter.yaml

# Deploy ServiceMonitor
echo -e "${YELLOW}Deploying ServiceMonitor for Prometheus...${NC}"
kubectl apply -f $CLUSTER_DIR/servicemonitor.yaml

# Deploy Kibana if requested
if [ "$WITH_KIBANA" = true ]; then
    echo -e "${YELLOW}Deploying Kibana...${NC}"
    kubectl apply -f $CLUSTER_DIR/kibana.yaml
    kubectl apply -f $CLUSTER_DIR/ingress.yaml

    echo -e "${YELLOW}Waiting for Kibana to be ready...${NC}"
    kubectl wait --for=condition=Ready kibana/kibana-eu -n elasticsearch --timeout=300s

    echo -e "${GREEN}Kibana deployed!${NC}"
    echo "Kibana URL: https://kibana.eu.k3s.canhnv.com"
fi

# Deploy Grafana dashboard and alerts
echo -e "${YELLOW}Deploying Grafana dashboard and alerts...${NC}"
MONITORING_DIR="$(cd "$SCRIPT_DIR/../../../monitoring/clusters/eu" && pwd)"
kubectl apply -f $MONITORING_DIR/elasticsearch-dashboard-configmap.yaml
kubectl apply -f $MONITORING_DIR/elasticsearch-prometheus-alerts.yaml

echo ""
echo -e "${GREEN}Deployment completed!${NC}"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo "Elasticsearch (internal): https://elasticsearch-eu-es-http.elasticsearch:9200"
echo "Username: elastic"
echo "Password: $ES_PASSWORD"
echo ""
echo "Grafana Dashboard: https://grafana.eu.k3s.canhnv.com"
