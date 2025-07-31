# Dev Cluster Monitoring

This document covers the monitoring setup specific to the development cluster.

## Overview

The dev cluster runs a complete Prometheus and Grafana stack for monitoring all services and infrastructure.

## Access Information

- **Grafana**: https://grafana.dev.k3s.canhnv.com
- **Username**: admin
- **Password**: Retrieved from Kubernetes secret (see below)

## Components

| Component | Purpose | Resources |
|-----------|---------|-----------|
| Prometheus | Metrics storage | 250m CPU, 1Gi RAM |
| Grafana | Visualization | 50m CPU, 128Mi RAM |
| Alertmanager | Alert routing | 50m CPU, 64Mi RAM |
| Node Exporter | Node metrics | Per node |
| kube-state-metrics | K8s metrics | 50m CPU, 64Mi RAM |

## Getting Started

### Access Grafana

1. Get admin password:
   ```bash
   kubectl get secret -n monitoring kube-prometheus-stack-grafana \
     -o jsonpath="{.data.admin-password}" | base64 -d
   ```

2. Access via browser: https://grafana.dev.k3s.canhnv.com

### Access Prometheus (Internal)

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then access http://localhost:9090
```

## Monitored Services

The following services are automatically monitored:

### System Components
- All K3s nodes (via Node Exporter)
- Kubernetes API server
- CoreDNS
- Traefik ingress controller

### Application Services
- PostgreSQL databases (postgres-db namespace)
- Redis instances (redis namespace)
- RabbitMQ (rabbitmq namespace)
- Custom applications with metrics endpoints

## Adding Service Monitoring

### Method 1: ServiceMonitor (Recommended)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
```

### Method 2: Pod Annotations

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  # ... pod spec
```

## Custom Dashboards

### Adding a Dashboard

1. Create dashboard in Grafana UI
2. Export as JSON
3. Create ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "My Custom Dashboard",
        "panels": [...]
      }
    }
```

4. Apply: `kubectl apply -f my-dashboard.yaml`

## Alerts

### Default Alerts

The stack includes pre-configured alerts for:
- Node down
- High CPU/Memory usage
- Disk space low
- Pod crashes
- Kubernetes component health

### Custom Alerts

Add PrometheusRule resources:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
spec:
  groups:
  - name: my-app
    rules:
    - alert: MyAppDown
      expr: up{job="my-app"} == 0
      for: 5m
      annotations:
        summary: "My App is down"
```

## Resource Usage

Current allocations (can be adjusted):
- **Prometheus Storage**: 30Gi (30-day retention)
- **Grafana Storage**: 5Gi
- **Total Memory**: ~2Gi across all components
- **Total CPU**: ~500m across all components

## Maintenance

### Check Component Health

```bash
# All monitoring pods
kubectl get pods -n monitoring

# Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Update Configuration

```bash
# Edit values
vim monitoring/clusters/dev/values.yaml

# Redeploy
./monitoring/scripts/deploy.sh dev
```

### Backup Dashboards

```bash
./monitoring/scripts/backup-dashboards.sh dev
```

## Troubleshooting

### Grafana Not Accessible

1. Check ingress: `kubectl get ingress -n monitoring`
2. Check certificate: `kubectl get certificate -n monitoring`
3. Check pod: `kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana`

### Missing Metrics

1. Check Prometheus targets: http://localhost:9090/targets
2. Verify ServiceMonitor: `kubectl get servicemonitor -A`
3. Check pod annotations: `kubectl describe pod <pod-name>`

### High Resource Usage

1. Check current usage: `kubectl top pods -n monitoring`
2. Review expensive queries in Grafana
3. Adjust retention if needed

## Integration with Dev Workflow

### Local Development

Forward Prometheus for local app testing:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Configure local app to send metrics to localhost:9090
```

### CI/CD Integration

Add monitoring checks to pipelines:
```bash
# Check if service is up
curl -s "http://localhost:9090/api/v1/query?query=up{job='my-app'}" | jq '.data.result[0].value[1]'
```