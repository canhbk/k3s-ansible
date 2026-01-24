# Kafka Deployment for K3s Clusters

Apache Kafka deployment using Strimzi Kafka Operator in KRaft mode (no Zookeeper).

## Overview

This directory contains Kubernetes manifests and deployment scripts for running Apache Kafka on K3s clusters using the Strimzi Kafka Operator. The deployment uses KRaft mode, which eliminates the need for Zookeeper by using Kafka's built-in consensus protocol.

## Directory Structure

```
kafka/
├── README.md                          # This file
├── base/
│   ├── namespace.yaml                 # Kafka namespace definition
│   └── strimzi-operator/
│       └── install.sh                 # Strimzi operator installation script
├── clusters/
│   └── us/                           # US cluster-specific configuration
│       ├── README.md                  # US cluster Kafka documentation
│       ├── kafka-cluster.yaml         # Kafka cluster configuration
│       ├── kafka-nodepools.yaml       # KRaft node pools (controllers + brokers)
│       ├── kafka-topics.yaml          # Default topic definitions
│       ├── kafka-users.yaml           # User ACLs and authentication
│       ├── podmonitor.yaml            # Prometheus metrics monitoring
│       └── ingress.yaml               # Kafka UI ingress (optional)
└── scripts/
    └── deploy.sh                      # Automated deployment script
```

## Prerequisites

Before deploying Kafka, ensure you have:

1. **Kubernetes Cluster**: K3s cluster running with kubectl access
2. **Helm**: Helm 3.x installed for Strimzi operator deployment
3. **Storage Class**: Longhorn storage class available (`longhorn-replicated`)
4. **Monitoring Stack**: Prometheus operator for metrics collection (optional)
5. **Cert-Manager**: For TLS certificate management (optional, for UI)

## Quick Start

### 1. Deploy to US Cluster

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/kafka

# Deploy to US cluster
./scripts/deploy.sh

# Or with dry-run to preview changes
./scripts/deploy.sh -d

# Deploy to a different cluster
./scripts/deploy.sh -c sg3
```

### 2. Manual Deployment Steps

If you prefer manual deployment:

```bash
# Switch to US cluster context
kubectl config use-context us

# Step 1: Install Strimzi Operator
./base/strimzi-operator/install.sh

# Step 2: Create namespace
kubectl apply -f base/namespace.yaml

# Step 3: Deploy node pools
kubectl apply -f clusters/us/kafka-nodepools.yaml

# Step 4: Deploy Kafka cluster
kubectl apply -f clusters/us/kafka-cluster.yaml

# Wait for cluster to be ready
kubectl wait kafka/kafka-us --for=condition=Ready --timeout=600s -n kafka

# Step 5: Create topics
kubectl apply -f clusters/us/kafka-topics.yaml

# Step 6: Create users
kubectl apply -f clusters/us/kafka-users.yaml

# Step 7: Setup monitoring
kubectl apply -f clusters/us/podmonitor.yaml
```

## Components

### Strimzi Kafka Operator

- **Version**: 0.50.0
- **Purpose**: Manages Kafka cluster lifecycle
- **Namespace**: kafka
- **Resources**: 100m CPU / 256Mi memory (requests)

### Kafka Cluster

- **Name**: kafka-us
- **Version**: 3.9.0
- **Mode**: KRaft (no Zookeeper)
- **Architecture**: Separated controllers and brokers

#### Node Pools

1. **Controllers** (kafka-controllers)
   - Replicas: 1
   - Role: Cluster metadata management
   - Storage: 1Gi persistent volume
   - Resources: 512Mi memory / 100m CPU

2. **Brokers** (kafka-brokers)
   - Replicas: 2
   - Role: Message processing and storage
   - Storage: 5Gi persistent volume per broker
   - Resources: 1Gi memory / 500m CPU (requests)
   - Anti-affinity: Spread across different nodes

### Listeners

| Name | Port | Type | TLS | Authentication | Usage |
|------|------|------|-----|----------------|-------|
| plain | 9092 | internal | No | None | Internal cluster communication |
| tls | 9093 | internal | Yes | None | Internal secure communication |
| external | 9094 | loadbalancer | Yes | SCRAM-SHA-512 | External client access |

### Default Topics

| Topic | Partitions | Replicas | Retention | Purpose |
|-------|-----------|----------|-----------|---------|
| events | 6 | 2 | 7 days | Application events |
| dlq | 3 | 2 | 30 days | Dead letter queue |

### Default Users

| User | Type | Permissions | Usage |
|------|------|-------------|-------|
| kafka-admin | SCRAM-SHA-512 | Full cluster access | Administration |
| app-user | SCRAM-SHA-512 | Read/Write to events, dlq topics | Application access |

## Common Operations

### Get Cluster Status

```bash
# Check Kafka cluster status
kubectl get kafka -n kafka

# Check node pools
kubectl get kafkanodepools -n kafka

# Check running pods
kubectl get pods -n kafka

# Check services
kubectl get svc -n kafka
```

### Retrieve User Credentials

```bash
# Get admin password
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d

# Get app-user password
kubectl get secret app-user -n kafka -o jsonpath='{.data.password}' | base64 -d
```

### Create New Topic

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-us
spec:
  partitions: 3
  replicas: 2
  config:
    retention.ms: 604800000
    cleanup.policy: delete
    min.insync.replicas: 1
EOF
```

### Create New User

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-app
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-us
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Write
          - Describe
      - resource:
          type: group
          name: my-app-*
          patternType: prefix
        operations:
          - Read
EOF
```

### Scale Brokers

```bash
# Edit broker node pool
kubectl edit kafkanodepool kafka-brokers -n kafka

# Change replicas value, e.g., from 2 to 3
```

### View Metrics

```bash
# Check if PodMonitors are active
kubectl get podmonitors -n kafka

# Port-forward to Prometheus to view metrics
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Then open http://localhost:9090
```

## Connection Examples

### From Inside Kubernetes

```bash
# Bootstrap server (plain)
kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092

# Bootstrap server (TLS)
kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093
```

### From Outside Kubernetes

```bash
# Get external LoadBalancer IP
kubectl get svc kafka-us-kafka-external-bootstrap -n kafka

# Connect using the external IP:9094 with TLS and SCRAM-SHA-512 authentication
```

### Example Producer (using kafkacat/kcat)

```bash
# Inside cluster (plain)
kubectl run -it --rm kafka-producer --image=edenhill/kcat:1.7.1 --restart=Never -- \
  -b kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  -t events -P

# With authentication (TLS + SCRAM)
kubectl run -it --rm kafka-producer --image=edenhill/kcat:1.7.1 --restart=Never -- \
  -b kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093 \
  -t events -P \
  -X security.protocol=SASL_SSL \
  -X sasl.mechanism=SCRAM-SHA-512 \
  -X sasl.username=app-user \
  -X sasl.password=<password>
```

## Monitoring

### Prometheus Metrics

The deployment includes PodMonitors for:
- Kafka brokers and controllers
- Entity Operator (Topic/User operators)
- Cruise Control

Metrics are exposed on the following endpoints:
- Kafka pods: `tcp-prometheus` port
- Entity Operator: `healthcheck` port
- Cruise Control: `rest-api` port

### Grafana Dashboards

Import Strimzi Kafka dashboards:
1. Kafka Dashboard ID: 11962
2. Cruise Control Dashboard ID: 12483
3. Kafka Exporter Dashboard ID: 7589

## Troubleshooting

### Cluster Not Starting

```bash
# Check operator logs
kubectl logs -n kafka -l name=strimzi-cluster-operator

# Check Kafka pod logs
kubectl logs -n kafka -l strimzi.io/cluster=kafka-us -c kafka

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kafka

# Check Longhorn volumes
kubectl get volumes -n longhorn-system
```

### Authentication Failures

```bash
# Verify user secret exists
kubectl get secret <username> -n kafka

# Check user status
kubectl get kafkauser <username> -n kafka -o yaml
```

### Topic Not Created

```bash
# Check topic operator logs
kubectl logs -n kafka -l strimzi.io/name=kafka-us-entity-operator -c topic-operator

# Check topic status
kubectl get kafkatopic <topic-name> -n kafka -o yaml
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n kafka

# View Cruise Control recommendations
kubectl exec -it kafka-us-cruise-control-0 -n kafka -- \
  curl http://localhost:9090/kafkacruisecontrol/state
```

## Upgrade Kafka Version

To upgrade Kafka version:

1. Edit kafka-cluster.yaml
2. Update `spec.kafka.version` field
3. Apply the change:
   ```bash
   kubectl apply -f clusters/us/kafka-cluster.yaml
   ```
4. Strimzi will perform a rolling upgrade automatically

## Uninstall

```bash
# Delete Kafka resources
kubectl delete kafka kafka-us -n kafka
kubectl delete kafkanodepool --all -n kafka

# Delete topics and users
kubectl delete kafkatopics --all -n kafka
kubectl delete kafkausers --all -n kafka

# Uninstall Strimzi operator
helm uninstall strimzi-kafka-operator -n kafka

# Delete namespace (will delete PVCs if deleteClaim: true)
kubectl delete namespace kafka
```

## Security Considerations

1. **Authentication**: External listener uses SCRAM-SHA-512
2. **TLS Encryption**: Enabled for external and internal TLS listeners
3. **Authorization**: ACL-based authorization for users
4. **Network Policies**: Consider adding NetworkPolicies for pod communication
5. **Secrets Management**: User credentials stored as Kubernetes secrets

## Additional Resources

- [Strimzi Documentation](https://strimzi.io/docs/operators/latest/overview.html)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [KRaft Mode](https://kafka.apache.org/documentation/#kraft)
- [Strimzi Metrics](https://strimzi.io/docs/operators/latest/deploying.html#assembly-metrics-str)
