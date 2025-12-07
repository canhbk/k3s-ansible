#!/bin/bash
# Dev Cluster Service Restoration Script
# Created: 2025-11-02
# Run this after master node migration to restore all services

set -e

echo "=================================="
echo "Dev Cluster Service Restoration"
echo "=================================="
echo ""

# Check if we're in the right context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "dev" ]; then
    echo "ERROR: Not in dev context. Current: $CURRENT_CONTEXT"
    echo "Run: kubectl config use-context dev"
    exit 1
fi

echo "✓ Using context: dev"
echo ""

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "  Waiting for $deployment in $namespace..."
    kubectl wait --for=condition=Available deployment/$deployment -n $namespace --timeout=300s
}

# Function to wait for statefulset
wait_for_statefulset() {
    local namespace=$1
    local sts=$2
    local replicas=$3
    echo "  Waiting for $sts in $namespace..."
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=$replicas statefulset/$sts -n $namespace --timeout=300s
}

##############################################
# 1. Longhorn Storage (Optional)
##############################################
echo "Step 1: Longhorn Storage"
echo "------------------------"
read -p "Deploy Longhorn storage? (y/N): " deploy_longhorn
if [[ "$deploy_longhorn" =~ ^[Yy]$ ]]; then
    echo "Installing Longhorn..."
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.0/deploy/longhorn.yaml
    echo "✓ Longhorn deployed (will take a few minutes to become ready)"
else
    echo "⊘ Skipping Longhorn"
fi
echo ""

##############################################
# 2. InfluxDB
##############################################
echo "Step 2: InfluxDB Time-Series Database"
echo "--------------------------------------"
if [ -d "monitoring/clusters/dev/influxdb" ]; then
    echo "Deploying InfluxDB..."
    kubectl create namespace influxdb --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f monitoring/clusters/dev/influxdb/
    echo "✓ InfluxDB deployed"
else
    echo "⊘ InfluxDB manifests not found"
fi
echo ""

##############################################
# 3. Redis
##############################################
echo "Step 3: Redis Clusters"
echo "----------------------"
if [ -d "redis/clusters/dev" ]; then
    echo "Deploying Redis..."
    kubectl create namespace redis --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f redis/clusters/dev/
    echo "✓ Redis deployed"
else
    echo "⊘ Redis manifests not found"
fi
echo ""

##############################################
# 4. RabbitMQ
##############################################
echo "Step 4: RabbitMQ Message Broker"
echo "-------------------------------"
if [ -d "rabbitmq/clusters/dev" ]; then
    echo "Deploying RabbitMQ..."
    kubectl create namespace rabbitmq --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f rabbitmq/clusters/dev/
    echo "✓ RabbitMQ deployed"
else
    echo "⊘ RabbitMQ manifests not found"
fi
echo ""

##############################################
# 5. Rancher (Helm)
##############################################
echo "Step 5: Rancher Management UI"
echo "-----------------------------"
read -p "Deploy Rancher? (y/N): " deploy_rancher
if [[ "$deploy_rancher" =~ ^[Yy]$ ]]; then
    echo "Installing Rancher via Helm..."
    kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -

    # Add Helm repo if not exists
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest 2>/dev/null || true
    helm repo update

    # Install Rancher
    helm upgrade --install rancher rancher-latest/rancher \
        --namespace cattle-system \
        --set hostname=rancher.dev.canhnv.com \
        --set bootstrapPassword=admin \
        --set replicas=1

    echo "✓ Rancher deployed"
    echo "  Access at: https://rancher.dev.canhnv.com"
    echo "  Initial password: admin"
else
    echo "⊘ Skipping Rancher"
fi
echo ""

##############################################
# 6. Prometheus & Grafana
##############################################
echo "Step 6: Prometheus & Grafana Monitoring"
echo "---------------------------------------"
if [ -d "monitoring/clusters/dev" ]; then
    echo "Deploying Prometheus & Grafana..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Deploy prometheus-operator if available
    if [ -f "monitoring/clusters/dev/prometheus-operator.yaml" ]; then
        kubectl apply -f monitoring/clusters/dev/prometheus-operator.yaml
    fi

    # Deploy other monitoring components
    find monitoring/clusters/dev -name "*.yaml" -type f -exec kubectl apply -f {} \;

    echo "✓ Monitoring stack deployed"
else
    echo "⊘ Monitoring manifests not found"
fi
echo ""

##############################################
# 7. PostgreSQL LoadBalancer Services
##############################################
echo "Step 7: PostgreSQL LoadBalancer Services"
echo "----------------------------------------"
read -p "Expose PostgreSQL via LoadBalancer? (y/N): " expose_pg
if [[ "$expose_pg" =~ ^[Yy]$ ]]; then
    echo "Creating LoadBalancer services..."
    if [ -f "database/postgresql/clusters/dev/postgres-murror-ai-loadbalancer.yaml" ]; then
        kubectl apply -f database/postgresql/clusters/dev/postgres-murror-ai-loadbalancer.yaml
    fi
    if [ -f "database/postgresql/clusters/dev/postgres-murror-be-loadbalancer.yaml" ]; then
        kubectl apply -f database/postgresql/clusters/dev/postgres-murror-be-loadbalancer.yaml
    fi
    if [ -f "database/postgresql/clusters/dev/postgres-vps-management-loadbalancer.yaml" ]; then
        kubectl apply -f database/postgresql/clusters/dev/postgres-vps-management-loadbalancer.yaml
    fi
    echo "✓ PostgreSQL LoadBalancers created"
else
    echo "⊘ Skipping PostgreSQL LoadBalancers"
fi
echo ""

##############################################
# Summary
##############################################
echo "=================================="
echo "Restoration Complete!"
echo "=================================="
echo ""
echo "Next Steps:"
echo "1. Check cluster status:"
echo "   kubectl get pods -A"
echo ""
echo "2. Wait for PostgreSQL cluster to be ready:"
echo "   kubectl get cluster -n postgres-db"
echo "   kubectl get pods -n postgres-db"
echo ""
echo "3. Verify services:"
echo "   kubectl get svc -A"
echo ""
echo "4. Check specific service status:"
echo "   kubectl get pods -n influxdb"
echo "   kubectl get pods -n redis"
echo "   kubectl get pods -n rabbitmq"
echo "   kubectl get pods -n cattle-system"
echo "   kubectl get pods -n monitoring"
echo ""
echo "5. Application namespaces need to be restored from your git repository"
echo ""
echo "For detailed status:"
echo "   kubectl top nodes"
echo "   kubectl get events -A --sort-by='.lastTimestamp' | tail -20"
echo ""
