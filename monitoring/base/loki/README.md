# Loki Base Configuration

This directory contains the base configuration for Grafana Loki log aggregation system, used across all K3s clusters.

## Overview

Loki is a horizontally scalable, highly available log aggregation system inspired by Prometheus. It indexes metadata (labels) instead of full-text, making it cost-effective and performant for Kubernetes log aggregation.

## Deployment Mode

**Simple Scalable Deployment (SSD)**

The SSD mode separates Loki into three main components:
- **Write Path** (distributors + ingesters): Handles log ingestion
- **Read Path** (query-frontend + queriers): Handles log queries
- **Backend** (compactor): Handles compaction and retention enforcement

This mode provides:
- Production-ready high availability
- Horizontal scalability up to "few TBs per day"
- Simpler operations than microservices mode
- Efficient resource usage for medium-sized clusters

## Base Configuration

### values-base.yaml

The base values file (`values-base.yaml`) defines:

**Storage Schema:**
- Schema version: v13 with TSDB index (latest recommended)
- Storage backend: Filesystem (PVC-backed)
- Index prefix: `index_`
- Index period: 24h

**Retention Policy:**
- Retention period: 15 days (360h)
- Compaction interval: 2h
- Retention delete delay: 2h

**Rate Limits:**
- Ingestion rate: 5MB/s per stream
- Ingestion burst: 15MB
- Max streams per user: 10,000
- Max global streams: 50,000

**Query Limits:**
- Max query parallelism: 32 concurrent queries
- Query split interval: 15m
- Max query series: 10,000

**Components:**
- Backend (compactor): 1 replica, 50Gi storage
- Read (queriers): 2 replicas, 50Gi storage
- Write (ingesters): 3 replicas, 50Gi storage
- Gateway (NGINX): 2 replicas

### Promtail Configuration

Promtail is deployed as a DaemonSet to collect logs from all nodes:

**Features:**
- Auto-discovery of all Kubernetes pods
- CRI log format parsing
- Kubernetes metadata enrichment (namespace, pod, container, labels)
- JSON log parsing
- Log level extraction
- Filtering of noisy system logs (svclb-* pods)

**Metadata Labels Added:**
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name
- `node`: Node name
- `app`: App label from pod
- `app_name`: app.kubernetes.io/name label
- `component`: app.kubernetes.io/component label
- `phase`: Pod phase (Running, Pending, etc.)

## Cluster-Specific Overrides

Each cluster should create a `monitoring/clusters/{cluster}/loki-values.yaml` file to override:

**Required Overrides:**
```yaml
backend:
  persistence:
    storageClass: <storage-class-name>  # e.g., longhorn, local-path
  resources:
    requests:
      cpu: <cpu-request>
      memory: <memory-request>

read:
  persistence:
    storageClass: <storage-class-name>
  resources:
    requests:
      cpu: <cpu-request>
      memory: <memory-request>

write:
  persistence:
    storageClass: <storage-class-name>
  resources:
    requests:
      cpu: <cpu-request>
      memory: <memory-request>

loki:
  commonConfig:
    replication_factor: <1-3>  # Based on cluster size
```

**Optional Overrides:**
- Storage sizes (if different from 50Gi)
- Replica counts (based on cluster size and load)
- Resource limits
- Retention period (if longer/shorter than 15 days)
- External labels for multi-cluster setups

## Deployment

### Prerequisites

1. Kubernetes cluster with kubectl access
2. Helm 3 installed
3. Storage class available (e.g., longhorn, local-path)
4. Monitoring namespace created

### Installation

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy Loki with base and cluster-specific values
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values monitoring/base/loki/values-base.yaml \
  --values monitoring/clusters/<cluster>/loki-values.yaml \
  --timeout 10m \
  --wait
```

### Verification

```bash
# Check pods (expect: 3 write + 2 read + 1 backend + 2 gateway + N promtail)
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Check PVCs (expect: 3 bound PVCs for write/read/backend)
kubectl get pvc -n monitoring | grep loki

# Test Loki ready endpoint
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://loki-gateway.monitoring.svc.cluster.local/ready

# Query logs
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -G http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/query \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=10'
```

## Integration

### Grafana Datasource

Create a ConfigMap for auto-provisioning:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki-gateway.monitoring.svc.cluster.local
      isDefault: false
      editable: true
```

### Prometheus ServiceMonitor

Monitor Loki metrics with Prometheus:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: loki
  namespace: monitoring
  labels:
    prometheus: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: loki
      app.kubernetes.io/component: gateway
  endpoints:
  - port: http-metrics
    interval: 30s
    path: /metrics
```

## Common LogQL Queries

```logql
# All logs from a namespace
{namespace="monitoring"}

# Logs from specific app
{app="prometheus"}

# Logs containing error
{namespace="monitoring"} |= "error"

# JSON logs with level filter
{namespace="monitoring"} | json | level="error"

# Logs from specific pod pattern
{pod=~"postgres-.*"}

# Rate of error logs
rate({namespace="monitoring"} |= "error" [5m])

# Count logs by level
sum by (level) (count_over_time({namespace="monitoring"}[5m]))
```

## Troubleshooting

### Logs Not Appearing

1. **Check Promtail pods:**
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
   kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=100
   ```

2. **Check Promtail is discovering pods:**
   ```bash
   kubectl port-forward -n monitoring daemonset/loki-promtail 3101:3101
   curl http://localhost:3101/targets
   ```

3. **Check Loki ingester:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/component=write --tail=100
   ```

### High Memory Usage

- Reduce `max_query_parallelism` in limits config
- Reduce `max_streams_per_user`
- Increase `split_queries_by_interval`
- Add more replicas to read/write components

### Slow Queries

- Reduce query time range
- Use more specific label selectors
- Avoid regex filters when possible
- Increase read replicas

### Storage Issues

- Check PVC status: `kubectl get pvc -n monitoring`
- Check Longhorn volumes (if using): `kubectl get volumes -n longhorn-system | grep loki`
- Monitor disk usage: `kubectl exec -n monitoring deployment/loki-write -- df -h`

## Architecture Diagram

```
┌─────────────┐
│   Promtail  │ (DaemonSet on each node)
│ (Log Agent) │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│  Loki Gateway    │ (NGINX Load Balancer)
│   (2 replicas)   │
└────┬────────┬────┘
     │        │
     ▼        ▼
┌────────┐ ┌────────┐
│ Write  │ │  Read  │
│(3 rep) │ │(2 rep) │
│        │ │        │
│Ingesters│ │Queriers│
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
┌──────────────────┐
│     Backend      │
│   (1 replica)    │
│   (Compactor)    │
└──────────────────┘
         │
         ▼
   ┌────────────┐
   │ Longhorn   │
   │  Storage   │
   │ (3 replicas)│
   └────────────┘
```

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Simple Scalable Deployment](https://grafana.com/docs/loki/latest/get-started/deployment-modes/#simple-scalable)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/query/)
- [Loki Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/loki)
