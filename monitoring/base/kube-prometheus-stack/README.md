# Kube-Prometheus-Stack Base Configuration

This directory contains the base Helm values for the kube-prometheus-stack deployment across all clusters.

## Key Configuration

### Retention Policy

- **Metrics Retention**: 30 days (1 month)
- **Max Storage Size**: 50GB per Prometheus instance
- **Actual Storage**: 60Gi PVC to accommodate retention

### Resource Allocation

- **Prometheus**: 500m CPU / 2Gi RAM (request), 4Gi RAM (limit)
- **Grafana**: 100m CPU / 128Mi RAM (request), 512Mi RAM (limit)
- **Alertmanager**: 50m CPU / 64Mi RAM (request), 128Mi RAM (limit)
- **Node Exporter**: 50m CPU / 32Mi RAM (request), 64Mi RAM (limit)

### Storage Classes

All persistent volumes use `local-path` storage class by default. This can be overridden per cluster.

### K3s Specific Configuration

- Disabled components that K3s doesn't expose:
  - kube-controller-manager
  - kube-scheduler
  - kube-proxy (K3s uses different implementation)
  - etcd (embedded in K3s)
- Added custom scrape configs for K3s components

## Customization per Cluster

Each cluster should create its own values file that includes:

```yaml
# Include base values
global:
  additionalLabels:
    cluster: <cluster-name>

# Override any base values as needed
prometheus:
  prometheusSpec:
    externalLabels:
      cluster: <cluster-name>
      region: <region>
      environment: <dev|staging|production>
```

## Dashboard Management

Grafana is configured to:

1. Auto-discover dashboards from ConfigMaps labeled with `grafana_dashboard: "1"`
2. Allow UI updates to dashboards
3. Organize dashboards in folders (default and K3s)
4. Search for dashboards in all namespaces
