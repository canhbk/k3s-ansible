# ClickHouse on SG3 Cluster

Single-node ClickHouse deployment for analytics/OLAP and event tracking workloads.

## Architecture

- **Image**: `clickhouse/clickhouse-server:24.12-alpine` (LTS)
- **Node**: vps55 (6 CPU, 12GB RAM)
- **Storage**: 30GB on `longhorn-retain`
- **Resources**: 2-4 CPU, 4-8GB memory

## Access

### External (via Ingress)

| Endpoint | URL |
|----------|-----|
| HTTP API | `https://clickhouse.sg3.k3s.canhnv.com` |
| Play UI  | `https://clickhouse.sg3.k3s.canhnv.com/play` |

### Internal (within cluster)

| Protocol | Address |
|----------|---------|
| HTTP     | `http://clickhouse.clickhouse.svc.cluster.local:8123` |
| Native   | `clickhouse.clickhouse.svc.cluster.local:9000` |
| Metrics  | `http://clickhouse.clickhouse.svc.cluster.local:9363/metrics` |

### Port Forwarding

```bash
kubectl --context sg3 port-forward -n clickhouse svc/clickhouse 8123:8123
kubectl --context sg3 port-forward -n clickhouse svc/clickhouse 9000:9000
```

## Users

| User | Access | Profile | Notes |
|------|--------|---------|-------|
| `default` | localhost only | default | Disabled for remote |
| `admin` | full access | default | `access_management: 1` |
| `app` | analytics, events, system DBs | app | 10k queries/hour quota |

## Deployment

### Prerequisites

1. Copy secrets template and fill in actual values:

```bash
cp secrets.yaml secrets.local.yaml
# Edit secrets.local.yaml — replace <CHANGE_ME_*> placeholders
# Generate SHA256 hash: echo -n 'your-password' | sha256sum
```

2. Ensure `longhorn-retain` StorageClass exists on the cluster.

### Deploy

```bash
cd database/clickhouse/scripts
./deploy.sh sg3
```

### Create Initial Databases

```bash
curl 'https://clickhouse.sg3.k3s.canhnv.com/?user=admin&password=<pw>' \
  --data 'CREATE DATABASE analytics'
curl 'https://clickhouse.sg3.k3s.canhnv.com/?user=admin&password=<pw>' \
  --data 'CREATE DATABASE events'
```

## Operations

### Backup

```bash
# Backup using clickhouse-backup (recommended for production)
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "BACKUP DATABASE analytics TO Disk('backups', 'analytics_$(date +%Y%m%d).zip')"

# Simple table export
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "SELECT * FROM analytics.my_table FORMAT Native" > backup.native
```

### Restore

```bash
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "RESTORE DATABASE analytics FROM Disk('backups', 'analytics_20240101.zip')"
```

### Check Status

```bash
# Pod status
kubectl --context sg3 get pods -n clickhouse

# ClickHouse version
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' --query "SELECT version()"

# Current queries
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' --query "SELECT * FROM system.processes"

# Database sizes
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "SELECT database, formatReadableSize(sum(bytes_on_disk)) FROM system.parts GROUP BY database"
```

### Scaling

Current setup is single-node. For HA, see the upgrade path in the main plan:
1. Install Altinity ClickHouse Operator
2. Create `ClickHouseInstallation` CRD
3. Migrate existing PVC to operator-managed deployment

## Monitoring

- **Prometheus**: ServiceMonitor scrapes `:9363/metrics` every 30s
- **Grafana**: Dashboard auto-provisioned as "ClickHouse Overview"
- **Alerts**: ClickHouseDown, HighMemory, TooManyParts, RejectedInserts, HighQueryRate, DiskUsage

## Troubleshooting

### Pod not starting

```bash
kubectl --context sg3 describe pod -n clickhouse clickhouse-0
kubectl --context sg3 logs -n clickhouse clickhouse-0
```

### High memory usage

```bash
# Check current memory
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "SELECT formatReadableSize(sum(value)) FROM system.metrics WHERE metric = 'MemoryTracking'"

# Kill heavy queries
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "KILL QUERY WHERE elapsed > 120"
```

### Too many parts

```bash
# Check parts count
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "SELECT database, table, count() as parts FROM system.parts WHERE active GROUP BY database, table ORDER BY parts DESC"

# Force merge
kubectl --context sg3 exec -n clickhouse clickhouse-0 -- \
  clickhouse-client --user admin --password '<pw>' \
  --query "OPTIMIZE TABLE analytics.my_table FINAL"
```
