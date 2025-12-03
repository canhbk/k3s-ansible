# InfluxDB - SG3 Production Cluster

Production cluster configuration for InfluxDB time-series database.

## Configuration

- **Organization**: Subeo
- **Default Bucket**: production
- **Retention**: 60 days
- **Storage**: 20Gi (Longhorn distributed storage)
- **Resources**: Production-grade (1-4Gi memory, 500m-2 CPU)

## Access

- **Web UI**: https://influxdb.sg3.k3s.canhnv.com
- **API Endpoint**: https://influxdb.sg3.k3s.canhnv.com
- **Internal**: http://influxdb-influxdb2.influxdb.svc.cluster.local:8086

## Deployment

### Deploy to SG3

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/database/influxdb/scripts
./deploy.sh sg3
```

### Get Admin Credentials

```bash
# Username: admin
# Password:
kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

### Port Forward for Local Access

```bash
kubectl port-forward -n influxdb svc/influxdb-influxdb2 8086:8086
# Access at: http://localhost:8086
```

## Monitoring

### Check Pod Status

```bash
kubectl get pods -n influxdb -l app.kubernetes.io/name=influxdb2
```

### Verify Prometheus Scraping

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n influxdb

# Port-forward to Prometheus and check targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets (look for influxdb)
```

## Integration

### Connection from Applications

```yaml
INFLUXDB_URL: "http://influxdb-influxdb2.influxdb.svc.cluster.local:8086"
INFLUXDB_ORG: "Subeo"
INFLUXDB_BUCKET: "production"
INFLUXDB_TOKEN: "<YOUR_TOKEN>"
```

See main documentation at `/Users/canhnv/development/canhnv/k3s-ansible/database/influxdb/README.md` for detailed usage.
