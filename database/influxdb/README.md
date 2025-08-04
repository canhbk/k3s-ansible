# InfluxDB for K3s Clusters

This directory contains the InfluxDB 2.x time-series database deployment for all K3s clusters.

## Overview

InfluxDB is deployed as a time-series database for storing metrics, events, and real-time analytics data across our K3s clusters. We use InfluxDB 2.x which provides:

- **Unified API**: Single API for ingest, query, storage, and visualization
- **Flux Query Language**: Powerful data scripting and query language
- **Built-in Visualization**: Native UI for data exploration
- **Retention Policies**: Automatic data lifecycle management
- **Multi-tenancy**: Organizations and buckets for data isolation

## Directory Structure

```
influxdb/
├── base/                        # Base configurations shared across clusters
│   ├── namespace.yaml          # InfluxDB namespace definition
│   ├── influxdb/              # Base Helm values
│   │   └── values-base.yaml
│   └── secrets/               # Secret templates
│       └── admin-secret.yaml
├── clusters/                   # Cluster-specific configurations
│   ├── dev/                   # Development cluster
│   ├── production/            # Production template
│   └── <cluster>/            # Other clusters (eu, jp, sg, sg2, us, vn, vn2)
└── scripts/                   # Deployment and maintenance scripts
    └── deploy.sh
```

## Quick Start

### Deploy to Dev Cluster

```bash
cd database/influxdb
./scripts/deploy.sh dev
```

### Deploy to Production Clusters

1. Copy the production template:

   ```bash
   cp -r clusters/production clusters/<cluster-name>
   ```

2. Update the configuration files:
   - Edit `clusters/<cluster-name>/values.yaml`
   - Edit `clusters/<cluster-name>/ingress.yaml`
   - Replace `CLUSTER_NAME` with actual cluster name

3. Create a secure admin password:

   ```bash
   openssl rand -base64 32
   ```

4. Create `clusters/<cluster-name>/admin-secret.yaml` with the password

5. Deploy:

   ```bash
   ./scripts/deploy.sh <cluster-name>
   ```

## Access

Each cluster has its own InfluxDB instance:

- **Dev**: <https://influxdb.dev.k3s.canhnv.com>
- **EU**: <https://influxdb.eu.k3s.canhnv.com>
- **JP**: <https://influxdb.jp.k3s.canhnv.com>
- **SG**: <https://influxdb.sg.k3s.canhnv.com>
- **SG2**: <https://influxdb.sg2.k3s.canhnv.com>
- **US**: <https://influxdb.us.k3s.canhnv.com>
- **VN**: <https://influxdb.vn.k3s.canhnv.com>
- **VN2**: <https://influxdb.vn2.k3s.canhnv.com>

### CLI Access

```bash
# Port forward to local machine
kubectl port-forward -n influxdb svc/influxdb 8086:8086

# Use influx CLI
influx config create --config-name k3s-dev \
  --host-url http://localhost:8086 \
  --org k3s-dev \
  --token <your-token>
```

### Internal Access (Within Cluster)

Applications within the cluster can access InfluxDB using:

```
http://influxdb.influxdb.svc.cluster.local:8086
```

## Configuration

### Storage

- **Dev**: 10Gi with 7-day retention
- **Production**: 100Gi+ with 90-day retention
- **Storage Classes**:
  - Default: `local-path`
  - VN clusters: `longhorn-vn`

### Resources

#### Development

```yaml
requests:
  memory: 256Mi
  cpu: 100m
limits:
  memory: 1Gi
  cpu: 500m
```

#### Production

```yaml
requests:
  memory: 1Gi
  cpu: 500m
limits:
  memory: 4Gi
  cpu: 2000m
```

### Authentication

- Admin credentials stored in Kubernetes secrets
- Token-based authentication for applications
- Organization-based multi-tenancy

## Integration

### Prometheus Remote Write

Configure Prometheus to write to InfluxDB:

```yaml
remoteWrite:
- url: http://influxdb.influxdb.svc.cluster.local:8086/api/v1/prom/write?org=k3s&bucket=prometheus
  headers:
    Authorization: Token <your-token>
```

### Telegraf Integration

Deploy Telegraf for additional metrics collection:

```yaml
[outputs.influxdb_v2]
  urls = ["http://influxdb.influxdb.svc.cluster.local:8086"]
  token = "<your-token>"
  organization = "k3s"
  bucket = "telegraf"
```

### Application Integration

Example connection in various languages:

#### Python

```python
from influxdb_client import InfluxDBClient

client = InfluxDBClient(
    url="http://influxdb.influxdb.svc.cluster.local:8086",
    token="<your-token>",
    org="k3s"
)
```

#### Go

```go
client := influxdb2.NewClient(
    "http://influxdb.influxdb.svc.cluster.local:8086",
    "<your-token>"
)
```

## Backup and Restore

### Manual Backup

```bash
# Port forward
kubectl port-forward -n influxdb svc/influxdb 8086:8086

# Backup
influx backup /path/to/backup \
  --host http://localhost:8086 \
  --token <your-token>
```

### Automated Backups

Production clusters have automated daily backups configured. Check `values.yaml` for S3 configuration.

### Restore

```bash
influx restore /path/to/backup \
  --host http://localhost:8086 \
  --token <your-token>
```

## Monitoring

InfluxDB metrics are automatically collected by Prometheus via ServiceMonitor. Available metrics:

- HTTP request rates and latencies
- Query performance
- Storage usage
- Write throughput

Access metrics in Grafana or query Prometheus directly.

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n influxdb
kubectl describe pod -n influxdb <pod-name>
kubectl logs -n influxdb <pod-name>
```

### Common Issues

1. **Pod not starting**: Check storage class availability

   ```bash
   kubectl get storageclass
   kubectl get pvc -n influxdb
   ```

2. **Authentication failures**: Verify secret exists

   ```bash
   kubectl get secret -n influxdb influxdb-auth
   ```

3. **High memory usage**: Check retention policies and cardinality

   ```bash
   influx bucket list
   ```

### Performance Tuning

For high-throughput workloads:

1. Increase resources in `values.yaml`
2. Adjust WAL settings:

   ```yaml
   config:
     storage:
       wal_fsync_delay: "1s"
       cache_max_memory_size: 2073741824
   ```

3. Enable TSI if needed for high cardinality

## Security Considerations

1. **TLS**: All external access uses HTTPS via cert-manager
2. **Authentication**: Token-based auth required for all API access
3. **Network Policies**: Consider implementing for production
4. **Secrets**: Rotate admin passwords regularly
5. **RBAC**: Use InfluxDB's built-in RBAC for fine-grained access

## Maintenance

### Upgrade InfluxDB

1. Update image tag in `base/influxdb/values-base.yaml`
2. Test in dev cluster first
3. Run deployment script for each cluster

### Clean Up Old Data

```bash
# Delete data older than retention policy
influx delete --org k3s --bucket <bucket> \
  --start '1970-01-01T00:00:00Z' \
  --stop $(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)
```

## Support

For issues or questions:

1. Check InfluxDB logs: `kubectl logs -n influxdb -l app.kubernetes.io/name=influxdb2`
2. Access InfluxDB UI for diagnostics
3. Review Prometheus metrics for performance issues
