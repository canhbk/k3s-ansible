# Kafka - US Cluster

Apache Kafka deployment using Strimzi Operator in KRaft mode (no Zookeeper).

Last Updated: 2026-01-24

## Quick Reference

| Property | Value |
|----------|-------|
| Namespace | `kafka` |
| Cluster Name | `kafka-us` |
| Kafka Version | 3.9.0 |
| Strimzi Version | 0.50.0 |
| Mode | KRaft (no Zookeeper) |
| Controller Replicas | 1 |
| Broker Replicas | 2 |
| Storage Class | longhorn-replicated |
| Status | Active |

## Connection Strings

### Internal (from within Kubernetes)

```bash
# Plain connection (no auth, port 9092)
kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092

# TLS connection (no auth, port 9093)
kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093

# External with auth (SCRAM-SHA-512, port 9094)
# Use LoadBalancer IP - check with:
kubectl get svc kafka-us-kafka-external-bootstrap -n kafka
```

### Connection Parameters

```properties
# For internal TLS + Auth
bootstrap.servers=kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="<username>" \
  password="<password>";
```

## Default Topics

| Topic | Partitions | Replicas | Retention | Purpose |
|-------|-----------|----------|-----------|---------|
| events | 6 | 2 | 7 days | Application events |
| dlq | 3 | 2 | 30 days | Dead letter queue |

## Users

| Username | Type | Permissions |
|----------|------|-------------|
| kafka-admin | SCRAM-SHA-512 | Full cluster access |
| app-user | SCRAM-SHA-512 | Read/Write to events, dlq topics |

### Get User Credentials

```bash
# Admin password
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d && echo

# App user password
kubectl get secret app-user -n kafka -o jsonpath='{.data.password}' | base64 -d && echo

# Get complete JAAS config
kubectl get secret app-user -n kafka -o jsonpath='{.data.sasl\.jaas\.config}' | base64 -d
```

## Services

```bash
# Bootstrap services
kafka-us-kafka-bootstrap           ClusterIP      9092, 9093
kafka-us-kafka-external-bootstrap  LoadBalancer   9094

# Individual broker access
kafka-us-kafka-brokers-0          ClusterIP      9092, 9093
kafka-us-kafka-brokers-1          ClusterIP      9092, 9093
```

## Architecture

- **Controllers (1 replica)**: Manage cluster metadata, 1Gi storage
- **Brokers (2 replicas)**: Handle messages, 5Gi storage each
- **Entity Operator**: Manages topics and users automatically
- **Cruise Control**: Cluster balancing and optimization

## Quick Operations

### Check Status

```bash
# Switch context
kubectl config use-context us

# Cluster status
kubectl get kafka kafka-us -n kafka

# Pods
kubectl get pods -n kafka

# Topics
kubectl get kafkatopics -n kafka

# Users
kubectl get kafkausers -n kafka
```

### Create Topic

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
  partitions: 6
  replicas: 2
  config:
    retention.ms: 604800000
    cleanup.policy: delete
EOF
```

### Create User

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
        operations: [Read, Write, Describe]
      - resource:
          type: group
          name: my-app-*
          patternType: prefix
        operations: [Read]
EOF
```

### Test Connection

```bash
# Producer test
kubectl run -it --rm kafka-test --image=quay.io/strimzi/kafka:0.50.0-kafka-3.9.0 \
  --restart=Never -n kafka -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic events

# Consumer test
kubectl run -it --rm kafka-test --image=quay.io/strimzi/kafka:0.50.0-kafka-3.9.0 \
  --restart=Never -n kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic events \
  --from-beginning
```

## Monitoring

### Prometheus Metrics

Metrics exposed via PodMonitors:
- Kafka cluster metrics (brokers, controllers)
- Entity Operator metrics
- Cruise Control metrics

### Grafana Dashboards

Import these dashboard IDs in Grafana:
- 11962: Strimzi Kafka
- 12483: Cruise Control
- 7589: Kafka Exporter

### Key Metrics

```promql
# Message throughput
rate(kafka_server_brokertopicmetrics_messagesinpersec[5m])

# Bytes in/out
rate(kafka_server_brokertopicmetrics_bytesinpersec[5m])
rate(kafka_server_brokertopicmetrics_bytesoutpersec[5m])

# Under-replicated partitions (should be 0)
kafka_server_replicamanager_underreplicatedpartitions
```

## Troubleshooting

### View Logs

```bash
# Operator logs
kubectl logs -n kafka -l name=strimzi-cluster-operator --tail=50

# Broker logs
kubectl logs -n kafka kafka-us-kafka-brokers-0 -c kafka --tail=50

# Topic operator logs
kubectl logs -n kafka -l strimzi.io/name=kafka-us-entity-operator -c topic-operator
```

### Common Issues

1. **Topic not created**: Check topic operator logs
2. **Auth failures**: Verify user secret exists and password is correct
3. **Storage issues**: Check PVC status and Longhorn volumes
4. **Performance**: Check resource usage with `kubectl top pods -n kafka`

## Documentation

For detailed documentation:
- [Kafka Main Documentation](/Users/canhnv/development/canhnv/k3s-ansible/kafka/README.md)
- [US Cluster Kafka README](/Users/canhnv/development/canhnv/k3s-ansible/kafka/clusters/us/README.md)
- [Strimzi Docs](https://strimzi.io/docs/operators/latest/overview.html)

## Deployment

Deployment managed via:
- **Location**: `/Users/canhnv/development/canhnv/k3s-ansible/kafka/`
- **Deploy Script**: `./scripts/deploy.sh`
- **Manifests**: `./clusters/us/`

## Verification Commands

```bash
# Verify deployment
kubectl config use-context us
kubectl get all -n kafka

# Check cluster is ready
kubectl get kafka kafka-us -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Should output: True

# List all resources
kubectl get kafka,kafkanodepools,kafkatopics,kafkausers,svc,pvc -n kafka
```
