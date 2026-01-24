# Loki Log Aggregation System

## Overview

Loki is a horizontally scalable, highly available log aggregation system inspired by Prometheus. It indexes metadata (labels) instead of full-text, making it cost-effective and performant for Kubernetes log aggregation.

**Key Features:**
- **Label-based indexing**: Only indexes metadata, not log content
- **Cost-effective**: Requires less storage and compute than traditional log aggregation
- **Native Grafana integration**: Built by Grafana Labs, seamless integration
- **Multi-tenancy**: Support for multiple isolated log streams
- **LogQL**: Prometheus-inspired query language

## Deployment Architecture

### Simple Scalable Deployment (SSD)

Loki is deployed using the Simple Scalable Deployment mode, which separates components into three logical groups:

```
┌─────────────┐
│   Promtail  │ (DaemonSet on each node)
│ (Log Agent) │ Collects logs from all pods
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│  Loki Gateway    │ (NGINX Load Balancer)
│   (2 replicas)   │ Entry point for all requests
└────┬────────┬────┘
     │        │
     ▼        ▼
┌────────┐ ┌────────┐
│ Write  │ │  Read  │
│(3 rep) │ │(2 rep) │  Horizontal scaling by function
│        │ │        │
│Ingesters│ │Queriers│
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
┌──────────────────┐
│     Backend      │ (Compactor)
│   (1 replica)    │ Handles retention and compaction
└──────────────────┘
         │
         ▼
   ┌────────────┐
   │ Longhorn   │
   │  Storage   │
   │ (3 replicas)│ Persistent log storage
   └────────────┘
```

## Cluster Deployments

### SG3 Cluster

**Status**: Deployed ✅
**Deployment Date**: 2025-12-02
**Namespace**: monitoring
**Retention**: 15 days

**Access Information:**
- **External URL**: https://loki.sg3.k3s.canhnv.com
- **Internal URL**: http://loki-gateway.monitoring.svc.cluster.local
- **Grafana Datasource**: Auto-configured (name: "Loki")

**Resource Allocation:**
- **CPU**: ~3.25 cores
- **Memory**: ~6.3Gi
- **Storage**: 150Gi persistent (450Gi raw with 3x replication)

**Components:**
- Write Path: 3 replicas, 50Gi each
- Read Path: 2 replicas, 50Gi each
- Backend: 1 replica, 50Gi
- Gateway: 2 replicas (no storage)
- Promtail: 8 pods (DaemonSet on all nodes)

**Configuration Files:**
- Base: `monitoring/base/loki/values-base.yaml`
- SG3: `monitoring/clusters/sg3/loki-values.yaml`
- Ingress: `monitoring/clusters/sg3/loki-ingress.yaml`
- Datasource: `monitoring/clusters/sg3/loki-datasource.yaml`
- Alerts: `monitoring/clusters/sg3/loki-alerts.yaml`

## Accessing Logs

### Via Grafana (Recommended)

1. Navigate to https://grafana.sg3.k3s.canhnv.com
2. Click on "Explore" (compass icon)
3. Select "Loki" datasource from dropdown
4. Enter LogQL query (examples below)
5. Click "Run query"

### Via LogCLI (Command Line)

```bash
# Install LogCLI
brew install logcli  # macOS
# or download from https://github.com/grafana/loki/releases

# Set Loki URL
export LOKI_ADDR=https://loki.sg3.k3s.canhnv.com

# Query logs
logcli query '{namespace="monitoring"}'

# Stream logs (like tail -f)
logcli query --tail '{pod="prometheus-0"}'

# Query with time range
logcli query --from="2h" --to="1h" '{namespace="postgres-db"} |= "error"'
```

### Via API (curl)

```bash
# From within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -G http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/query \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=100'

# From outside cluster (if ingress configured)
curl -G https://loki.sg3.k3s.canhnv.com/loki/api/v1/query \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=100'
```

## LogQL Query Examples

### Basic Label Queries

```logql
# All logs from a namespace
{namespace="monitoring"}

# All logs from a specific pod
{pod="prometheus-0"}

# All logs from pods matching a pattern
{pod=~"postgres-.*"}

# All logs with specific app label
{app="prometheus"}

# Multiple label selectors (AND)
{namespace="monitoring", app="prometheus"}

# Label selector with regex (OR)
{namespace=~"monitoring|postgres-db"}
```

### Line Filters

```logql
# Contains "error" (case-sensitive)
{namespace="monitoring"} |= "error"

# Does NOT contain "info"
{namespace="monitoring"} != "info"

# Regex match
{namespace="monitoring"} |~ "error|warning"

# Case-insensitive contains
{namespace="monitoring"} |~ "(?i)error"
```

### Parsing and Filtering

```logql
# Parse JSON logs and filter by field
{namespace="monitoring"} | json | level="error"

# Parse logfmt logs
{namespace="monitoring"} | logfmt | status_code="500"

# Extract and filter by pattern
{namespace="monitoring"} | pattern `<_> level=<level>` | level="error"

# Line format to customize output
{namespace="monitoring"} | line_format "{{.pod}}: {{.message}}"
```

### Aggregations and Metrics

```logql
# Count log lines over time
count_over_time({namespace="monitoring"}[5m])

# Rate of log lines (logs per second)
rate({namespace="monitoring"}[5m])

# Count of error logs
sum(count_over_time({namespace="monitoring"} |= "error" [5m]))

# Count logs by pod
sum by (pod) (count_over_time({namespace="monitoring"}[5m]))

# 95th percentile of request duration (from parsed logs)
quantile_over_time(0.95, {app="api"} | json | duration [5m])

# Bytes processed
sum(bytes_over_time({namespace="monitoring"}[5m]))
```

### Advanced Queries

```logql
# Error rate percentage
sum(rate({namespace="monitoring"} |= "error" [5m]))
  /
sum(rate({namespace="monitoring"}[5m])) * 100

# Top 10 pods by log volume
topk(10, sum by (pod) (count_over_time({namespace="monitoring"}[1h])))

# Logs with duration > 1s (parsed from JSON)
{app="api"} | json | duration > 1.0

# Filter by multiple conditions
{namespace="monitoring"}
  | json
  | level="error"
  | status_code >= 500
  | line_format "{{.pod}}: {{.message}}"
```

## Common Use Cases

### Debugging Application Errors

```logql
# Find all errors in the last hour
{namespace="my-app"} |= "error"

# Parse JSON logs and filter by level
{namespace="my-app"} | json | level="error" or level="fatal"

# Search for specific error messages
{app="api"} |~ "(?i)database connection failed"
```

### Monitoring Database Queries

```logql
# All PostgreSQL logs
{namespace="postgres-db"}

# Slow queries (parsed from logs)
{namespace="postgres-db"}
  | pattern `duration: <duration> ms`
  | duration > 1000

# Failed queries
{namespace="postgres-db"} |= "ERROR"
```

### Tracking HTTP Requests

```logql
# All 5xx errors
{app="nginx"} | json | status >= 500

# Request rate by status code
sum by (status) (rate({app="nginx"} | json [5m]))

# Top URLs by request count
topk(10, sum by (url) (count_over_time({app="nginx"} | json [1h])))
```

### Container Restarts

```logql
# Logs from recently restarted pods
{namespace="monitoring"} | json | __error__="" | line_format "{{.pod}}"

# Find crash logs
{namespace="monitoring"} |~ "panic|fatal|crashed"
```

## Deployment Guide

### Prerequisites

1. Kubernetes cluster with kubectl access
2. Helm 3 installed
3. Storage class available (Longhorn recommended)
4. Monitoring namespace created
5. Grafana deployed (for datasource integration)

### Deployment Steps

```bash
# 1. Switch to target cluster context
kubectl config use-context sg3

# 2. Deploy Loki
cd /Users/canhnv/development/canhnv/k3s-ansible/monitoring
./scripts/deploy-loki.sh sg3

# The script will:
# - Add Grafana Helm repository
# - Deploy Loki via Helm
# - Apply ingress configuration
# - Configure Grafana datasource
# - Set up Prometheus monitoring
# - Apply alert rules
# - Wait for all pods to be ready
```

### Manual Deployment (Alternative)

```bash
# Add Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy with custom values
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values monitoring/base/loki/values-base.yaml \
  --values monitoring/clusters/sg3/loki-values.yaml \
  --timeout 10m \
  --wait

# Apply additional manifests
kubectl apply -f monitoring/clusters/sg3/loki-ingress.yaml
kubectl apply -f monitoring/clusters/sg3/loki-datasource.yaml
kubectl apply -f monitoring/clusters/sg3/loki-servicemonitor.yaml
kubectl apply -f monitoring/clusters/sg3/loki-alerts.yaml
```

## Verification

### Check Deployment Status

```bash
# Check all Loki pods (expect 16 total)
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Check PVCs (expect 3: write, read, backend)
kubectl get pvc -n monitoring | grep loki

# Check services
kubectl get svc -n monitoring -l app.kubernetes.io/name=loki

# Check ingress and certificate
kubectl get ingress,certificate -n monitoring | grep loki
```

### Test Loki Functionality

```bash
# Test ready endpoint
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://loki-gateway.monitoring.svc.cluster.local/ready
# Expected: "ready"

# Query logs
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -G http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/query \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=10'
# Expected: JSON response with log entries

# Check Promtail is collecting logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50
# Expected: No errors, "level=info" messages
```

### Verify Grafana Integration

1. Open https://grafana.sg3.k3s.canhnv.com
2. Go to Configuration → Data sources
3. Verify "Loki" datasource shows green status
4. Go to Explore
5. Select "Loki" datasource
6. Run query: `{namespace="monitoring"}`
7. Should see logs from monitoring namespace

### Verify Prometheus Monitoring

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open http://localhost:9090/targets
# Search for "loki"
# Should show UP status
```

## Troubleshooting

### Logs Not Appearing

**Issue**: No logs showing in Grafana

**Diagnosis:**
```bash
# 1. Check Promtail pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail

# 2. Check Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=100

# 3. Check if Promtail is discovering pods
kubectl port-forward -n monitoring daemonset/loki-promtail 3101:3101
curl http://localhost:3101/targets
```

**Solutions:**
- Ensure Promtail DaemonSet is running on all nodes
- Check Promtail can reach Loki gateway
- Verify log path permissions
- Check for label selector mismatches

### High Memory Usage

**Issue**: Loki components consuming excessive memory

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=loki

# Check ingester chunks
kubectl exec -n monitoring deployment/loki-write -- wget -q -O- http://localhost:3100/metrics | grep loki_ingester_memory_chunks
```

**Solutions:**
- Reduce `max_query_parallelism` in configuration
- Decrease `max_streams_per_user`
- Increase `split_queries_by_interval`
- Add more read/write replicas
- Reduce retention period

### Slow Queries

**Issue**: Log queries taking too long

**Solutions:**
- Reduce query time range
- Use more specific label selectors
- Avoid regex filters when possible
- Enable caching in Grafana
- Increase read replicas
- Add `split_queries_by_interval`

### Storage Issues

**Issue**: PVCs not binding or running out of space

**Diagnosis:**
```bash
# Check PVC status
kubectl get pvc -n monitoring | grep loki

# Check Longhorn volumes
kubectl get volumes -n longhorn-system | grep loki

# Check disk usage
kubectl exec -n monitoring deployment/loki-write -- df -h
```

**Solutions:**
- Verify Longhorn is healthy
- Increase PVC size in values.yaml
- Reduce retention period
- Enable compaction
- Check for failed compaction jobs

### Certificate Issues

**Issue**: HTTPS not working for loki.sg3.k3s.canhnv.com

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificate -n monitoring | grep loki
kubectl describe certificate loki-sg3-tls -n monitoring

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

**Solutions:**
- Verify cert-manager is running
- Check DNS is pointing to cluster
- Verify ClusterIssuer exists
- Delete and recreate certificate

## Maintenance

### Upgrading Loki

```bash
# 1. Check current version
helm list -n monitoring | grep loki

# 2. Update Helm repository
helm repo update

# 3. Check available versions
helm search repo grafana/loki --versions | head -10

# 4. Upgrade (use same values files)
helm upgrade loki grafana/loki \
  --namespace monitoring \
  --values monitoring/base/loki/values-base.yaml \
  --values monitoring/clusters/sg3/loki-values.yaml \
  --timeout 10m \
  --wait

# 5. Verify upgrade
kubectl rollout status deployment/loki-write -n monitoring
kubectl rollout status deployment/loki-read -n monitoring
```

### Scaling Components

```bash
# Scale write path (ingesters)
# Edit monitoring/clusters/sg3/loki-values.yaml
# Change write.replicas to desired count
# Reapply with Helm

# Scale read path (queriers)
# Edit monitoring/clusters/sg3/loki-values.yaml
# Change read.replicas to desired count
# Reapply with Helm
```

### Backup and Recovery

Loki data is stored in Longhorn PVCs with 3-replica configuration:

1. **Automated Longhorn Snapshots**:
   ```bash
   # Configure recurring snapshots in Longhorn UI
   # Access: https://sg3.longhorn.canhnv.com
   ```

2. **Manual Backup**:
   ```bash
   # Take snapshot of each PVC via Longhorn UI or API
   kubectl get pvc -n monitoring | grep loki
   ```

3. **Recovery**:
   ```bash
   # Restore from Longhorn snapshot
   # Via Longhorn UI: Storage > Snapshots > Restore
   ```

### Adjusting Retention

```bash
# Edit monitoring/base/loki/values-base.yaml or cluster-specific values
# Change loki.limits_config.retention_period

# Example: Change from 15d to 30d
retention_period: 720h  # 30 days

# Redeploy
./scripts/deploy-loki.sh sg3
```

## Performance Tuning

### Ingestion Rate Limits

Configured in `monitoring/base/loki/values-base.yaml`:

```yaml
loki:
  limits_config:
    ingestion_rate_mb: 5       # MB/s per stream
    ingestion_burst_size_mb: 15  # Burst allowance
```

### Query Optimization

```yaml
loki:
  limits_config:
    max_query_parallelism: 32      # Concurrent query threads
    split_queries_by_interval: 15m  # Split large queries
    max_query_series: 10000         # Series per query
```

### Resource Allocation

Adjust in `monitoring/clusters/sg3/loki-values.yaml`:

```yaml
write:
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
```

## Monitoring Loki

Loki exports Prometheus metrics for self-monitoring:

### Key Metrics

```promql
# Ingestion rate (bytes/second)
rate(loki_distributor_bytes_received_total[5m])

# Request latency (99th percentile)
histogram_quantile(0.99, rate(loki_request_duration_seconds_bucket[5m]))

# Active streams
loki_ingester_streams

# Memory chunks
loki_ingester_memory_chunks

# Failed requests
rate(loki_request_duration_seconds_count{status_code=~"5.."}[5m])
```

### Alerts

Configured in `monitoring/clusters/sg3/loki-alerts.yaml`:

- **LokiRequestErrors**: >10% error rate for 15min
- **LokiRequestLatency**: p99 >1s for 15min
- **LokiWritePathDown**: Write component down for 5min
- **LokiReadPathDown**: Read component down for 5min
- **PromtailNotRunning**: <8 Promtail instances for 10min

## Best Practices

1. **Use Structured Logging**: JSON or logfmt for easier parsing
2. **Consistent Labels**: Use standard Kubernetes labels
3. **Limit Cardinality**: Avoid high-cardinality labels (e.g., timestamps, IDs)
4. **Query Optimization**: Use specific label selectors first, then filters
5. **Retention Planning**: Balance retention vs storage costs
6. **Resource Monitoring**: Watch memory usage of ingesters
7. **Regular Backups**: Enable Longhorn snapshots
8. **Alert on Anomalies**: Monitor ingestion rate, query latency, errors

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/query/)
- [Simple Scalable Deployment](https://grafana.com/docs/loki/latest/get-started/deployment-modes/#simple-scalable)
- [Loki Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/loki)
- [LogCLI Documentation](https://grafana.com/docs/loki/latest/tools/logcli/)
