# Monitoring on VN Cluster

## Overview

The VN cluster has comprehensive monitoring with metrics, logs, and alerting.

**Components:**
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Promtail**: Log collection from all nodes
- **Alertmanager**: Alert routing to Slack

## Access

| Service | URL |
|---------|-----|
| Grafana | `https://grafana.vn.k3s.canhnv.com` |
| Prometheus | `https://prometheus.vn.k3s.canhnv.com` |

**Grafana Credentials:**
- Username: `admin`
- Password: `prom-operator`

## Loki Log Aggregation

### Deployment

- **Mode**: SingleBinary (all-in-one pod)
- **Namespace**: monitoring
- **Storage**: 20Gi local-path
- **Retention**: 15 days (360 hours)

### Promtail Configuration

- Runs as DaemonSet on all nodes
- Collects logs from all pods
- Tenant ID: `1`

### Querying Logs

Via Grafana Explore:
1. Select "Loki" datasource
2. Use LogQL queries:

```logql
# All logs from a namespace
{namespace="nsp-prod-murror"}

# Error logs only
{namespace="nsp-prod-murror"} |= "ERROR"

# JSON parsed logs
{namespace="nsp-prod-murror"} | json
```

## Alert Routing

### Slack Channels

| Channel | Purpose |
|---------|---------|
| `#alert-production-database` | PostgreSQL alerts |
| `#alert-production-murror-api` | Murror API alerts |

### Alert Severity

- **critical**: Immediate action required, 30m repeat interval
- **warning**: Investigation needed, 1h repeat interval

## Murror API Monitoring

### Alerts

| Alert | Threshold | Severity |
|-------|-----------|----------|
| MurrorAPIPodNotReady | Pod not ready | warning |
| MurrorAPIPodRestarts | >3 restarts in 15m | warning |
| MurrorAPIContainerCrashLooping | Restart rate >0.05/sec | critical |
| MurrorAPIDeploymentReplicasMismatch | Replicas mismatch | warning |
| MurrorAPIHighErrorLogRate | >10 errors/sec | critical |
| MurrorAPIHighMemoryUsage | >85% memory limit | warning |
| MurrorAPIHighCPUUsage | >80% CPU limit | warning |
| MurrorAPINoPodsRunning | 0 pods running | critical |

### Grafana Dashboard

The Murror API dashboard includes:
- CPU/Memory usage gauges
- Pod resource metrics over time
- Live log streaming
- Error/Warn/Debug log panels
- Request volume and error rates

**Namespace Selector**: Supports multiple namespaces:
- `nsp-prod-murror`
- `nsp-prod-murror-ai`
- `murror-kol-prod-vn`

## Loki Health Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| LokiRequestErrors | Error rate >10% | warning |
| LokiRequestLatency | 99th percentile >1s | warning |
| LokiWritePathDown | Write component down | critical |
| LokiReadPathDown | Read component down | critical |
| PromtailNotRunning | <4 instances | warning |

## Configuration Files

```
monitoring/clusters/vn/
├── values.yaml                    # kube-prometheus-stack Helm values
├── ingress.yaml                   # Grafana/Prometheus ingress
├── loki-values.yaml               # Loki Helm values
├── loki-datasource.yaml           # Grafana Loki datasource
├── loki-servicemonitor.yaml       # Prometheus scraping Loki
├── loki-alerts.yaml               # Loki health alerts
├── murror-api-alerts.yaml         # Murror API alerts
└── murror-api-dashboard-configmap.yaml  # Grafana dashboard
```

## Maintenance Commands

```bash
# Check Prometheus targets
kubectl get servicemonitor -n monitoring

# Check alert rules
kubectl get prometheusrule -n monitoring

# Check Alertmanager status
kubectl exec -n monitoring deploy/alertmanager-kube-prometheus-stack-alertmanager -- \
  wget -qO- http://localhost:9093/api/v2/status

# View active alerts
kubectl exec -n monitoring deploy/alertmanager-kube-prometheus-stack-alertmanager -- \
  wget -qO- http://localhost:9093/api/v2/alerts | jq

# Check Loki logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=100

# Check Promtail status
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
```

## Last Updated

- Date: 2025-12-15
- Loki: Deployed with Promtail
- Murror API: Dashboard and alerts configured
- PostgreSQL: Alerts with production thresholds
