#!/bin/bash

# Deploy Kafka to US Cluster
# Usage: ./deploy.sh [-c cluster] [-d dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAFKA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER="${CLUSTER:-us}"
DRY_RUN=""

while getopts "c:d" opt; do
  case $opt in
    c) CLUSTER="$OPTARG" ;;
    d) DRY_RUN="--dry-run=client" ;;
    *) echo "Usage: $0 [-c cluster] [-d dry-run]"; exit 1 ;;
  esac
done

echo "======================================"
echo "Deploying Kafka to ${CLUSTER} cluster"
echo "======================================"

kubectl config use-context ${CLUSTER}

CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "$CLUSTER" ]; then
    echo "ERROR: Failed to switch to ${CLUSTER} context"
    exit 1
fi

echo "Current context: ${CURRENT_CONTEXT}"

echo ""
echo "Step 1: Installing Strimzi Operator..."
echo "---------------------------------------"
NAMESPACE=kafka ${KAFKA_DIR}/base/strimzi-operator/install.sh

echo ""
echo "Step 2: Creating namespace..."
echo "-----------------------------"
kubectl apply -f ${KAFKA_DIR}/base/namespace.yaml ${DRY_RUN}

echo ""
echo "Step 3: Waiting for Strimzi CRDs..."
echo "------------------------------------"
kubectl wait --for=condition=established crd/kafkas.kafka.strimzi.io --timeout=60s
kubectl wait --for=condition=established crd/kafkanodepools.kafka.strimzi.io --timeout=60s
kubectl wait --for=condition=established crd/kafkatopics.kafka.strimzi.io --timeout=60s
kubectl wait --for=condition=established crd/kafkausers.kafka.strimzi.io --timeout=60s

echo ""
echo "Step 4: Creating Kafka Node Pools..."
echo "-------------------------------------"
kubectl apply -f ${KAFKA_DIR}/clusters/${CLUSTER}/kafka-nodepools.yaml ${DRY_RUN}

echo ""
echo "Step 5: Creating Kafka Cluster..."
echo "----------------------------------"
kubectl apply -f ${KAFKA_DIR}/clusters/${CLUSTER}/kafka-cluster.yaml ${DRY_RUN}

echo ""
echo "Step 6: Waiting for Kafka cluster to be ready..."
echo "-------------------------------------------------"
if [ -z "$DRY_RUN" ]; then
    echo "This may take several minutes..."
    kubectl wait kafka/kafka-us --for=condition=Ready --timeout=600s -n kafka
fi

echo ""
echo "Step 7: Creating Kafka topics..."
echo "---------------------------------"
kubectl apply -f ${KAFKA_DIR}/clusters/${CLUSTER}/kafka-topics.yaml ${DRY_RUN}

echo ""
echo "Step 8: Creating Kafka users..."
echo "--------------------------------"
kubectl apply -f ${KAFKA_DIR}/clusters/${CLUSTER}/kafka-users.yaml ${DRY_RUN}

echo ""
echo "Step 9: Creating PodMonitors for Prometheus..."
echo "-----------------------------------------------"
kubectl apply -f ${KAFKA_DIR}/clusters/${CLUSTER}/podmonitor.yaml ${DRY_RUN}

echo ""
echo "======================================"
echo "Deployment Summary"
echo "======================================"
echo ""
echo "Cluster Status:"
kubectl get kafka -n kafka
echo ""
echo "Node Pools:"
kubectl get kafkanodepools -n kafka
echo ""
echo "Pods:"
kubectl get pods -n kafka
echo ""
echo "Services:"
kubectl get svc -n kafka
echo ""
echo "Topics:"
kubectl get kafkatopics -n kafka
echo ""
echo "Users:"
kubectl get kafkausers -n kafka

echo ""
echo "======================================"
echo "SUCCESS: Kafka deployed to ${CLUSTER} cluster!"
echo "======================================"
echo ""
echo "Connection Information:"
echo "-----------------------"
echo "Bootstrap Server (internal): kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092"
echo "Bootstrap Server (TLS):      kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093"
echo ""
echo "To get user credentials:"
echo "kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d"
echo ""
