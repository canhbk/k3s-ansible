# Dev Cluster Monitoring

This directory contains the monitoring configuration specific to the development cluster.

## Access

- **Grafana URL**: <https://grafana.dev.k3s.canhnv.com>
- **Prometheus URL**: Internal only (port-forward for access)

## Configuration Details

### Resource Allocation (Dev-optimized)

- **Prometheus**: 250m CPU / 1Gi RAM (request), 2Gi RAM (limit)
- **Grafana**: 50m CPU / 128Mi RAM (request), 256Mi RAM (limit)
- **Storage**: 30Gi for Prometheus, 5Gi for Grafana

### Ingress

- Uses Traefik ingress controller
- TLS certificate from `canhnv-com-staging` ClusterIssuer
- Accessible at grafana.dev.k3s.canhnv.com

### Labels

- cluster: dev
- environment: development
- region: us

## Deployment

```bash
# From monitoring directory
./scripts/deploy.sh dev
```

## Access Credentials

Get Grafana admin password:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

## Port-forwarding (for internal access)

Access Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Access Alertmanager:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

## Monitoring Dev Services

All services in the dev cluster are automatically discovered if they have:

1. ServiceMonitor CRDs
2. Pod annotations:

   ```yaml
   prometheus.io/scrape: "true"
   prometheus.io/port: "metrics"
   prometheus.io/path: "/metrics"
   ```

## Custom Dashboards

To add custom dashboards:

1. Create a ConfigMap with label `grafana_dashboard: "1"`
2. Apply it to any namespace (Grafana will auto-discover)

Example:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    {
      "dashboard": { ... }
    }
```
