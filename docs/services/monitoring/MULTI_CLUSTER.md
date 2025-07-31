# Multi-Cluster Monitoring Setup

This guide covers deploying and managing monitoring across multiple K3s clusters.

## Overview

Each K3s cluster runs its own monitoring stack to ensure:

- **Isolation**: Cluster failures don't affect monitoring of other clusters
- **Performance**: Metrics queries are local and fast
- **Scalability**: Each cluster scales independently
- **Security**: No cross-cluster network requirements

## Deployment Strategy

### 1. Base Configuration

All clusters share a common base configuration:

- `monitoring/base/kube-prometheus-stack/values-base.yaml`
- 30-day retention policy
- Standard resource allocations
- Common dashboards and alerts

### 2. Cluster-Specific Overrides

Each cluster has its own configuration directory:

```
monitoring/clusters/
├── dev/          # Development cluster
├── eu/           # Europe production
├── jp/           # Japan production
├── sg/           # Singapore primary
├── sg2/          # Singapore secondary
├── us/           # United States
├── vn/           # Vietnam primary
└── vn2/          # Vietnam secondary
```

### 3. Deployment Process

For each cluster:

```bash
# 1. Create cluster directory
mkdir -p monitoring/clusters/CLUSTER_NAME

# 2. Copy and customize templates
cp monitoring/clusters/production/values-template.yaml monitoring/clusters/CLUSTER_NAME/values.yaml
cp monitoring/clusters/production/ingress-template.yaml monitoring/clusters/CLUSTER_NAME/ingress.yaml

# 3. Edit configurations
# - Replace CLUSTER_NAME placeholders
# - Adjust resource limits
# - Configure region/environment labels

# 4. Deploy
./monitoring/scripts/deploy.sh CLUSTER_NAME

# 5. Verify
kubectl get pods -n monitoring
kubectl get ingress -n monitoring
```

## Configuration Guidelines

### Development Clusters

```yaml
# Lower resource allocation
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 30Gi
```

### Production Clusters

```yaml
# Higher resource allocation
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 1
        memory: 4Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 100Gi
    # Enable HA if needed
    replicas: 2
```

### Region-Specific Labels

```yaml
global:
  additionalLabels:
    cluster: sg
    environment: production
    region: asia-southeast
    datacenter: singapore-1
```

## DNS Configuration

Each cluster gets its own subdomain:

- Pattern: `grafana.{cluster}.k3s.canhnv.com`
- Certificate: Managed by cert-manager
- Issuer: `canhnv-com-staging` (or production)

## Monitoring Federation (Future)

For global visibility across clusters, consider:

### Option 1: Thanos

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Cluster 1  │     │  Cluster 2  │     │  Cluster 3  │
│ Prometheus  │     │ Prometheus  │     │ Prometheus  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Thanos    │
                    │   Query     │
                    └─────────────┘
```

### Option 2: Remote Write

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
    - url: https://central-prometheus.example.com/api/v1/write
      writeRelabelConfigs:
      - sourceLabels: [__name__]
        regex: 'expensive_metric.*'
        action: drop
```

### Option 3: Grafana Data Sources

- Add each cluster's Prometheus as a data source
- Create unified dashboards with cluster selector

## Maintenance

### Dashboard Synchronization

1. Export dashboards from one cluster:

   ```bash
   ./monitoring/scripts/backup-dashboards.sh dev
   ```

2. Import to other clusters:

   ```bash
   kubectl apply -f dashboard-backups/dev_*/namespace_*.yaml
   ```

### Bulk Updates

Update all clusters:

```bash
for cluster in dev eu jp sg sg2 us vn vn2; do
    echo "Updating $cluster..."
    ./monitoring/scripts/deploy.sh $cluster
done
```

### Health Checks

Monitor the monitoring stack:

```bash
# Check all clusters
for cluster in dev eu jp sg sg2 us vn vn2; do
    echo "Checking $cluster..."
    kubectl config use-context $cluster
    kubectl get pods -n monitoring | grep -E "0/|Error|CrashLoop"
done
```

## Best Practices

1. **Consistent Naming**: Use cluster name in all labels
2. **Resource Planning**: Size based on cluster workload
3. **Alert Routing**: Configure per-cluster alert channels
4. **Dashboard Versioning**: Use ConfigMaps for version control
5. **Regular Backups**: Schedule dashboard exports
6. **Access Control**: Implement RBAC per environment

## Troubleshooting

Common issues across clusters:

1. **Storage Full**
   - Check: `kubectl exec -n monitoring prometheus-0 -- df -h`
   - Solution: Increase PVC size or reduce retention

2. **High Memory Usage**
   - Check: `kubectl top pods -n monitoring`
   - Solution: Increase limits or optimize queries

3. **Ingress Issues**
   - Check: Certificate status
   - Verify: DNS resolution
   - Test: Internal service access

4. **Cross-Cluster Queries**
   - Use Grafana variables for cluster selection
   - Configure appropriate data sources
