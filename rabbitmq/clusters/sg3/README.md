# RabbitMQ HA Cluster - SG3

## Overview

High-availability RabbitMQ deployment on the SG3 cluster using the **official RabbitMQ Cluster Operator** with 3 replicas for zero-downtime operations.

- **Replicas**: 3 (high availability cluster)
- **Storage**: 6Gi total (2Gi per replica, Longhorn)
- **Domain**: https://rabbitmq.sg3.canhnv.com
- **Deployment Date**: 2025-11-26
- **Last Updated**: 2025-12-03 (upgraded to RabbitMQ 4.0.9)
- **Deployment Method**: RabbitMQ Cluster Operator (official)

## Quick Start for Applications

**Need to connect your app to RabbitMQ?** See [CONNECTION_INFO.md](./CONNECTION_INFO.md) for:
- Complete connection URLs and credentials
- Kubernetes secret templates ready to use
- Language-specific examples (Python, Node.js, Go, Java)
- Testing and troubleshooting guides

## High Availability Features

- **Zero-downtime deployments**: Rolling updates without service interruption
- **Node failure tolerance**: Survives 1 node failure with zero data loss
- **Automatic failover**: < 5 second failover time
- **Quorum queues**: Built-in replication via Raft consensus
- **Pod anti-affinity**: Replicas distributed across different nodes
- **Partition handling**: `pause_minority` strategy

## Deployment

### Prerequisites

```bash
# Switch to sg3 cluster
kubectl config use-context sg3

# Verify prerequisites
kubectl get clusterissuer canhnv-com-prod
kubectl get storageclass longhorn
kubectl get nodes  # Should show 8 nodes
```

### Install RabbitMQ Cluster Operator

```bash
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

# Verify operator is running
kubectl -n rabbitmq-system get pods
```

### Deploy RabbitMQ Cluster

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/sg3

kubectl create namespace rabbitmq
kubectl apply -f rabbitmq-cluster.yaml
kubectl apply -f ingress.yaml
```

### Monitor Deployment

```bash
# Watch pods come up (takes 2-3 minutes)
kubectl get pods -n rabbitmq -w

# Expected sequence:
# rabbitmq-server-0   0/1 -> 1/1  (first replica)
# rabbitmq-server-1   0/1 -> 1/1  (joins cluster)
# rabbitmq-server-2   0/1 -> 1/1  (joins cluster)
```

## Access

### Management UI

- **URL**: https://rabbitmq.sg3.canhnv.com
- **Credentials**: Retrieve with commands below

```bash
# Get username
kubectl get secret --namespace rabbitmq rabbitmq-default-user \
  -o jsonpath="{.data.username}" | base64 -d && echo

# Get password
kubectl get secret --namespace rabbitmq rabbitmq-default-user \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Internal Service (from pods)

```bash
# AMQP connection
rabbitmq.rabbitmq.svc.cluster.local:5672

# Management API
rabbitmq.rabbitmq.svc.cluster.local:15672

# Connection string format
amqp://<username>:<password>@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

### External LoadBalancer

```bash
# Get LoadBalancer IPs
kubectl get svc rabbitmq -n rabbitmq
```

## Operations

### Check Cluster Status

```bash
# Verify all 3 nodes are clustered
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl cluster_status

# Expected output:
# Cluster name: rabbitmq
# Running nodes: rabbit@rabbitmq-server-0, rabbit@rabbitmq-server-1, rabbit@rabbitmq-server-2
```

### Check Pod Status

```bash
# List all pods with nodes
kubectl get pods -n rabbitmq -o wide

# Verify each pod is on a different node
```

### Check Resources

```bash
# Check PVCs (should show 3, all Bound)
kubectl get pvc -n rabbitmq

# Check certificate
kubectl get certificate -n rabbitmq

# Check ingress
kubectl get ingress -n rabbitmq

# Check RabbitmqCluster CR
kubectl get rabbitmqcluster -n rabbitmq
```

### View Logs

```bash
# View logs from specific pod
kubectl logs -n rabbitmq rabbitmq-server-0 -f

# View logs from all pods
kubectl logs -n rabbitmq -l app.kubernetes.io/name=rabbitmq --tail=50
```

### Restart Cluster

```bash
# Delete pods one by one (StatefulSet will recreate them)
kubectl delete pod rabbitmq-server-0 -n rabbitmq
# Wait for it to rejoin, then continue with next pod
```

### Scale Replicas

```bash
# Scale up to 5 replicas
kubectl patch rabbitmqcluster rabbitmq -n rabbitmq --type merge \
  -p '{"spec":{"replicas":5}}'
```

## High Availability Management

### Test Failover

```bash
# Delete a pod to test automatic recovery
kubectl delete pod rabbitmq-server-1 -n rabbitmq

# Watch pod recreate and rejoin cluster
kubectl get pods -n rabbitmq -w

# Verify cluster reformed
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl cluster_status
```

### Check Queue Distribution

```bash
# List queues and their primary node
kubectl exec rabbitmq-server-0 -n rabbitmq -- \
  rabbitmqctl list_queues name node
```

## Monitoring

### Prometheus Metrics

Metrics are exposed on port 15692:

```bash
# Port-forward to access metrics locally
kubectl port-forward -n rabbitmq svc/rabbitmq 15692:15692

# Access metrics
curl http://localhost:15692/metrics
```

### Health Checks

```bash
# Run health checks
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmq-diagnostics status
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmq-diagnostics check_running
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmq-diagnostics check_local_alarms
```

## Backup and Recovery

### Export Definitions

```bash
# Export definitions (queues, exchanges, bindings, users, etc.)
kubectl exec rabbitmq-server-0 -n rabbitmq -- \
  rabbitmqctl export_definitions /tmp/definitions.json

# Copy to local machine
kubectl cp rabbitmq/rabbitmq-server-0:/tmp/definitions.json ./definitions-$(date +%Y%m%d).json
```

### Import Definitions

```bash
# Copy definitions to pod
kubectl cp ./definitions.json rabbitmq/rabbitmq-server-0:/tmp/definitions.json

# Import
kubectl exec rabbitmq-server-0 -n rabbitmq -- \
  rabbitmqctl import_definitions /tmp/definitions.json
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod rabbitmq-server-0 -n rabbitmq

# Check logs
kubectl logs rabbitmq-server-0 -n rabbitmq --previous

# Common issues:
# - Insufficient resources (check node capacity)
# - Storage not available (check Longhorn status)
# - Network connectivity (check Wireguard mesh)
```

### Longhorn Volume Mount Failure

If you see error "device is apparently in use by the system", this is caused by `multipathd` interfering with Longhorn block devices:

```bash
# Apply the multipath fix
kubectl apply -f ../../longhorn/clusters/sg3/fix-multipath-daemonset.yaml

# Wait for DaemonSet to complete
kubectl -n longhorn-system get pods -l app=fix-multipath-longhorn

# Delete the DaemonSet after fix is applied
kubectl -n longhorn-system delete daemonset fix-multipath-longhorn
```

### Check Operator Logs

```bash
kubectl logs -n rabbitmq-system deploy/rabbitmq-cluster-operator -f
```

### Cluster Formation Issues

```bash
# Check if pods can resolve each other
kubectl exec rabbitmq-server-0 -n rabbitmq -- nslookup rabbitmq-server-1.rabbitmq-nodes

# Force boot if quorum is lost (use with caution!)
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl force_boot
```

## Connection Examples

### Node.js (amqplib)

```javascript
const amqp = require('amqplib');

const connection = await amqp.connect({
  protocol: 'amqp',
  hostname: 'rabbitmq.rabbitmq.svc.cluster.local',
  port: 5672,
  username: process.env.RABBITMQ_USERNAME,
  password: process.env.RABBITMQ_PASSWORD,
  vhost: '/'
});
```

### Python (pika)

```python
import pika
import os

credentials = pika.PlainCredentials(
    os.environ['RABBITMQ_USERNAME'],
    os.environ['RABBITMQ_PASSWORD']
)
parameters = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5672,
    virtual_host='/',
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)
```

### Spring Boot (Java)

```yaml
spring:
  rabbitmq:
    host: rabbitmq.rabbitmq.svc.cluster.local
    port: 5672
    username: ${RABBITMQ_USERNAME}
    password: ${RABBITMQ_PASSWORD}
    virtual-host: /
```

## Resource Utilization

**Per Replica:**
- Memory: 2Gi request, 4Gi limit
- CPU: 500m request, 2 cores limit
- Storage: 2Gi Longhorn

**Total Cluster:**
- Memory: 6Gi request, 12Gi limit
- CPU: 1.5 cores request, 6 cores limit
- Storage: 6Gi persistent across 3 nodes

## Uninstall

```bash
# WARNING: This will delete all data!

# 1. Delete RabbitmqCluster CR
kubectl delete rabbitmqcluster rabbitmq -n rabbitmq

# 2. Delete PVCs (if you want to remove data)
kubectl delete pvc -n rabbitmq --all

# 3. Delete namespace
kubectl delete namespace rabbitmq

# 4. (Optional) Remove operator
kubectl delete -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
```

## Related Documentation

- [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ Clustering Guide](https://www.rabbitmq.com/clustering.html)
- [Longhorn Multipath Troubleshooting](https://longhorn.io/kb/troubleshooting-volume-with-multipath/)
