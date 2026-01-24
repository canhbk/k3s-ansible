# InfluxDB - Development Cluster

Development cluster configuration for InfluxDB.

## Configuration

- **Organization**: k3s-dev
- **Default Bucket**: dev
- **Retention**: 7 days
- **Storage**: 10Gi
- **Resources**: Reduced for development (256Mi-1Gi memory)

## Access

- **Web UI**: <https://influxdb.dev.k3s.canhnv.com>
- **API Endpoint**: <https://influxdb.dev.k3s.canhnv.com>
- **Internal**: <http://influxdb.influxdb.svc.cluster.local:8086>

## Features

- Debug logging enabled
- HTTP request logging enabled
- Shorter retention for development data
- ServiceMonitor for Prometheus integration

## Quick Commands

```bash
# Deploy
../../scripts/deploy.sh dev

# Get admin password
kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d

# Port forward for local access
kubectl port-forward -n influxdb svc/influxdb 8086:8086

# Check logs
kubectl logs -n influxdb -l app.kubernetes.io/name=influxdb2 -f
```

## Testing

Use this cluster for:

- Testing InfluxDB queries and performance
- Developing new integrations
- Experimenting with retention policies
- Testing backup/restore procedures
