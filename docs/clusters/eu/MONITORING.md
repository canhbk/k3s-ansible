# Monitoring Stack on EU Cluster

## Overview

The EU cluster runs a complete monitoring stack using kube-prometheus-stack, providing metrics collection, alerting, and visualization.

## Components

| Component | Version | Namespace | Status |
|-----------|---------|-----------|--------|
| Prometheus | Latest | monitoring | Running |
| Grafana | Latest | monitoring | Running |
| Alertmanager | Latest | monitoring | Running |
| Node Exporter | Latest | monitoring | Running |
| Kube State Metrics | Latest | monitoring | Running |

## Access

### Grafana

- **URL**: https://grafana.eu.k3s.canhnv.com
- **Username**: admin
- **Password**: Retrieve with:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d
  ```

### Prometheus (Internal)

- **Service**: `kube-prometheus-stack-prometheus.monitoring:9090`
- Port-forward for local access:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```

### Alertmanager (Internal)

- **Service**: `kube-prometheus-stack-alertmanager.monitoring:9093`

## Storage

| Component | PVC Size | Storage Class |
|-----------|----------|---------------|
| Prometheus | 30Gi | longhorn-replicated |
| Alertmanager | 5Gi | longhorn-replicated |
| Grafana | 5Gi | longhorn-replicated |

## Elasticsearch Monitoring

### Metrics Exporter

The Elasticsearch exporter (`quay.io/prometheuscommunity/elasticsearch-exporter:v1.8.0`) runs in the `elasticsearch` namespace and exposes metrics at port 9114.

### Grafana Dashboard

A pre-configured dashboard "Elasticsearch - EU Cluster" is available showing:
- Cluster health status
- Node count and shard distribution
- JVM heap memory and GC rates
- Indexing and search query rates
- Disk usage percentage

### Prometheus Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| ElasticsearchClusterHealthRed | Critical | Cluster health is red for 2m |
| ElasticsearchClusterHealthYellow | Warning | Cluster health is yellow for 10m |
| ElasticsearchNodesDown | Critical | Node count < 1 for 1m |
| ElasticsearchUnassignedShards | Warning | Unassigned shards > 0 for 5m |
| ElasticsearchDiskUsageHigh | Warning | Disk usage > 80% for 5m |
| ElasticsearchDiskUsageCritical | Critical | Disk usage > 90% for 2m |
| ElasticsearchJVMHeapUsageHigh | Warning | Heap usage > 85% for 5m |
| ElasticsearchHighGCRate | Warning | Old GC rate > 5/sec for 5m |

## Configuration Files

| File | Purpose |
|------|---------|
| `monitoring/clusters/eu/values.yaml` | Helm values for kube-prometheus-stack |
| `monitoring/clusters/eu/ingress.yaml` | Grafana ingress configuration |
| `monitoring/clusters/eu/elasticsearch-dashboard-configmap.yaml` | Grafana dashboard |
| `monitoring/clusters/eu/elasticsearch-prometheus-alerts.yaml` | Alert rules |

## Common Operations

### Check Prometheus Targets

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Check Alertmanager Status

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open http://localhost:9093
```

### View Prometheus Rules

```bash
kubectl get prometheusrules -A
```

### Restart Grafana

```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

## TLS/SSL Configuration

Both Grafana and Kibana use:
- **Ingress**: Traefik with TLS termination
- **Certificate Issuer**: `canhnv-com-prod` (Let's Encrypt)
- **DNS**: Proxied through Cloudflare

## Troubleshooting

### Grafana Not Loading

1. Check pod status:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
   ```

2. Check logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

### Prometheus Not Scraping Targets

1. Check ServiceMonitor:
   ```bash
   kubectl get servicemonitor -A
   ```

2. Verify target is reachable:
   ```bash
   kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- wget -qO- http://elasticsearch-exporter.elasticsearch:9114/metrics | head
   ```

---

**Last Updated**: 2026-01-25
