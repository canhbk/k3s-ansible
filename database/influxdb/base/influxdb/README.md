# Base InfluxDB Configuration

This directory contains the base Helm values that are shared across all InfluxDB deployments.

## Files

- `values-base.yaml`: Base configuration for InfluxDB 2.x Helm chart

## Key Configuration

### Storage

- Default: 50Gi with local-path storage class
- Clusters can override with their specific storage class and size

### Resources

Base resources suitable for most workloads:

- Requests: 512Mi memory, 250m CPU
- Limits: 2Gi memory, 1000m CPU

### Retention

- Default: 30 days
- Can be overridden per cluster

### Monitoring

- Prometheus ServiceMonitor enabled by default
- Metrics exposed for collection by kube-prometheus-stack

## Customization

Cluster-specific values files should import and override these base values as needed. Common overrides:

1. **Storage size and class**
2. **Resource limits**
3. **Retention policies**
4. **Organization and bucket names**
5. **Environment-specific labels**

## Helm Chart

We use the official InfluxData Helm chart:

- Repository: <https://helm.influxdata.com/>
- Chart: influxdb2
- Documentation: <https://github.com/influxdata/helm-charts/tree/master/charts/influxdb2>
