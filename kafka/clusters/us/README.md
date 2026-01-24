# Kafka Deployment - US Cluster

Apache Kafka deployment on the US K3s cluster using Strimzi Operator in KRaft mode.

## Cluster Information

| Property | Value |
|----------|-------|
| Cluster Name | kafka-us |
| Cluster Context | us |
| Namespace | kafka |
| Kafka Version | 3.9.0 |
| Strimzi Version | 0.50.0 |
| Mode | KRaft (no Zookeeper) |
| Storage Class | longhorn-replicated |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        US Kafka Cluster                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐     ┌──────────────────────────────┐ │
│  │   Controllers    │     │         Brokers               │ │
│  │   (Metadata)     │     │     (Message Storage)         │ │
│  ├──────────────────┤     ├──────────────────────────────┤ │
│  │  Replica: 1      │     │  Replicas: 2                 │ │
│  │  Storage: 1Gi    │     │  Storage: 5Gi each           │ │
│  │  CPU: 100m       │     │  CPU: 500m                   │ │
│  │  Memory: 512Mi   │     │  Memory: 1Gi                 │ │
│  └──────────────────┘     └──────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Entity Operator                         │  │
│  │  - Topic Operator (manages topics)                   │  │
│  │  - User Operator (manages users & ACLs)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Cruise Control                          │  │
│  │  - Cluster balancing and optimization                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Services

### Bootstrap Services

| Service Name | Type | Port | Protocol | Usage |
|-------------|------|------|----------|-------|
| kafka-us-kafka-bootstrap | ClusterIP | 9092 | PLAINTEXT | Internal clients |
| kafka-us-kafka-bootstrap | ClusterIP | 9093 | TLS | Internal clients (secure) |
| kafka-us-kafka-external-bootstrap | LoadBalancer | 9094 | TLS + SCRAM-SHA-512 | External clients |

### Individual Broker Services

| Service Name | Type | Usage |
|-------------|------|-------|
| kafka-us-kafka-brokers-0 | ClusterIP | Direct broker 0 access |
| kafka-us-kafka-brokers-1 | ClusterIP | Direct broker 1 access |

## Connection Information

### Internal (from within Kubernetes)

```bash
# Plain connection (no auth)
BOOTSTRAP_SERVERS=kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092

# TLS connection (no auth)
BOOTSTRAP_SERVERS=kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093

# TLS + Authentication
BOOTSTRAP_SERVERS=kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093
SECURITY_PROTOCOL=SASL_SSL
SASL_MECHANISM=SCRAM-SHA-512
SASL_USERNAME=<username>
SASL_PASSWORD=<password>
```

### External (from outside Kubernetes)

```bash
# Get external IP
kubectl get svc kafka-us-kafka-external-bootstrap -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Connection string
BOOTSTRAP_SERVERS=<external-ip>:9094
SECURITY_PROTOCOL=SASL_SSL
SASL_MECHANISM=SCRAM-SHA-512
SASL_USERNAME=<username>
SASL_PASSWORD=<password>
```

## Topics

### Default Topics

| Topic Name | Partitions | Replicas | Retention | Purpose |
|-----------|-----------|----------|-----------|---------|
| events | 6 | 2 | 7 days | Application events |
| dlq | 3 | 2 | 30 days | Dead letter queue for failed messages |

### Topic Configuration

Default topic settings:
- **Replication Factor**: 2
- **Min In-Sync Replicas**: 1
- **Cleanup Policy**: delete
- **Compression Type**: producer
- **Auto-create Topics**: Disabled (must create explicitly)

## Users

### Default Users

| Username | Authentication | Authorization | Purpose |
|----------|---------------|---------------|---------|
| kafka-admin | SCRAM-SHA-512 | Full cluster access | Administration |
| app-user | SCRAM-SHA-512 | Read/Write events, dlq topics | Application access |

### Retrieve User Credentials

```bash
# Admin user password
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d && echo

# App user password
kubectl get secret app-user -n kafka -o jsonpath='{.data.password}' | base64 -d && echo
```

### User Secrets Structure

Each KafkaUser creates a secret with the following keys:
- `password`: Base64-encoded SCRAM-SHA-512 password
- `sasl.jaas.config`: Complete JAAS configuration for clients

Example to get JAAS config:
```bash
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.sasl\.jaas\.config}' | base64 -d
```

## Monitoring

### Prometheus Metrics

Three PodMonitors are configured:
1. **kafka-cluster-metrics**: Broker and controller metrics
2. **kafka-entity-operator-metrics**: Topic/User operator metrics
3. **kafka-cruise-control-metrics**: Cruise Control metrics

### Key Metrics to Monitor

- `kafka_server_brokertopicmetrics_messagesinpersec`: Message throughput
- `kafka_server_brokertopicmetrics_bytesinpersec`: Bytes in per second
- `kafka_server_brokertopicmetrics_bytesoutpersec`: Bytes out per second
- `kafka_controller_kafkacontroller_activecontrollercount`: Active controllers
- `kafka_server_replicamanager_underreplicatedpartitions`: Under-replicated partitions
- `kafka_log_log_size`: Total log size per topic

### Grafana Dashboards

Recommended Grafana dashboard IDs:
- **11962**: Strimzi Kafka Dashboard
- **12483**: Kafka Cruise Control
- **7589**: Kafka Exporter

## Operations

### Check Cluster Health

```bash
# Switch to US cluster
kubectl config use-context us

# Check Kafka cluster status
kubectl get kafka kafka-us -n kafka

# Expected output:
# NAME       DESIRED KAFKA REPLICAS   DESIRED ZK REPLICAS   READY   WARNINGS
# kafka-us   3                                              True
```

### View All Resources

```bash
# All Kafka resources
kubectl get kafka,kafkanodepools,kafkatopics,kafkausers -n kafka

# Pods
kubectl get pods -n kafka

# Services
kubectl get svc -n kafka

# PVCs
kubectl get pvc -n kafka
```

### Test Connection

```bash
# Create a test producer pod
kubectl run -it --rm kafka-test --image=quay.io/strimzi/kafka:0.50.0-kafka-3.9.0 \
  --restart=Never -n kafka -- /bin/bash

# Inside the pod, produce a message
bin/kafka-console-producer.sh \
  --bootstrap-server kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic events

# Create a test consumer pod
kubectl run -it --rm kafka-consumer --image=quay.io/strimzi/kafka:0.50.0-kafka-3.9.0 \
  --restart=Never -n kafka -- /bin/bash

# Inside the pod, consume messages
bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic events \
  --from-beginning
```

### Create Application User

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-app-user
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
          name: events
          patternType: literal
        operations:
          - Read
          - Write
          - Describe
      - resource:
          type: group
          name: my-app
          patternType: prefix
        operations:
          - Read
EOF
```

### Create Application Topic

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-app-events
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-us
spec:
  partitions: 6
  replicas: 2
  config:
    retention.ms: 604800000  # 7 days
    segment.bytes: 1073741824  # 1GB
    cleanup.policy: delete
    min.insync.replicas: 1
    compression.type: producer
EOF
```

## Troubleshooting

### Common Issues

#### 1. Cluster Not Ready

```bash
# Check cluster status
kubectl describe kafka kafka-us -n kafka

# Check operator logs
kubectl logs -n kafka -l name=strimzi-cluster-operator --tail=100

# Check broker logs
kubectl logs -n kafka kafka-us-kafka-brokers-0 -c kafka --tail=100
```

#### 2. Topic Creation Failed

```bash
# Check topic operator logs
kubectl logs -n kafka -l strimzi.io/name=kafka-us-entity-operator \
  -c topic-operator --tail=50

# Check topic status
kubectl describe kafkatopic <topic-name> -n kafka
```

#### 3. User Authentication Failed

```bash
# Verify secret exists
kubectl get secret <username> -n kafka

# Check user status
kubectl describe kafkauser <username> -n kafka

# Verify password
kubectl get secret <username> -n kafka -o jsonpath='{.data.password}' | base64 -d
```

#### 4. Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kafka

# Check Longhorn volumes
kubectl get volumes -n longhorn-system | grep kafka

# Check disk usage
kubectl exec -it kafka-us-kafka-brokers-0 -n kafka -c kafka -- df -h
```

### Performance Tuning

#### Increase Broker Resources

Edit `kafka-nodepools.yaml`:
```yaml
spec:
  resources:
    requests:
      memory: 2Gi  # Increase from 1Gi
      cpu: 1000m   # Increase from 500m
    limits:
      memory: 4Gi  # Increase from 2Gi
      cpu: 2000m   # Increase from 1000m
```

Apply changes:
```bash
kubectl apply -f kafka-nodepools.yaml
```

#### Increase Storage

Edit `kafka-nodepools.yaml`:
```yaml
spec:
  storage:
    size: 10Gi  # Increase from 5Gi
```

Note: Storage size can only be increased, not decreased.

## Security

### TLS Certificates

Strimzi automatically generates TLS certificates for cluster communication:

```bash
# List certificates
kubectl get secrets -n kafka | grep kafka-us

# Cluster CA certificate
kubectl get secret kafka-us-cluster-ca-cert -n kafka

# Clients CA certificate
kubectl get secret kafka-us-clients-ca-cert -n kafka
```

### Network Policies

Consider adding NetworkPolicies to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kafka-network-policy
  namespace: kafka
spec:
  podSelector:
    matchLabels:
      strimzi.io/cluster: kafka-us
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: my-app-namespace
    ports:
    - protocol: TCP
      port: 9092
    - protocol: TCP
      port: 9093
```

## Backup and Recovery

### Topic Configuration Backup

```bash
# Export all topic definitions
kubectl get kafkatopics -n kafka -o yaml > kafka-topics-backup.yaml
```

### User Configuration Backup

```bash
# Export all user definitions
kubectl get kafkausers -n kafka -o yaml > kafka-users-backup.yaml
```

### Message Backup

Consider using:
- Kafka MirrorMaker 2 for replication
- Kafka Connect with S3 sink connector
- Cruise Control for topic data snapshots

## Additional Resources

For more detailed documentation, see:
- [Main Kafka Documentation](/Users/canhnv/development/canhnv/k3s-ansible/kafka/README.md)
- [US Cluster Kafka Guide](/Users/canhnv/development/canhnv/k3s-ansible/docs/clusters/us/KAFKA.md)
- [Strimzi Documentation](https://strimzi.io/docs/)
