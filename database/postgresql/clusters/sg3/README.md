# PostgreSQL with pgvector on SG3 Cluster

## Overview

High-availability PostgreSQL 17.2 cluster with pgvector and TimescaleDB extensions deployed on the sg3 Kubernetes cluster using CloudNativePG (CNPG) operator.

**Deployment Date**: November 25, 2025
**Cluster Name**: `postgresql-sg3-pgvector`
**Namespace**: `postgres-db`

## Cluster Configuration

### Architecture
- **Instances**: 3 (1 primary + 2 async replicas)
- **PostgreSQL Version**: 17.2
- **Extensions**: pgvector 0.8.0, TimescaleDB 2.x
- **Storage**: Longhorn (3-replica distributed storage)
- **High Availability**: Automatic failover enabled

### Resources
**Per Instance**:
- CPU: 500m request, 2 cores limit
- Memory: 2Gi request, 4Gi limit
- Storage: 20Gi per instance (60Gi total)

**Total Cluster**:
- CPU: 1.5 cores request, 6 cores limit
- Memory: 6Gi request, 12Gi limit
- Storage: 60Gi logical (180Gi physical with Longhorn 3-replica)

### Storage Details
- **Storage Class**: `longhorn` (default, 3 replicas)
- **Volume Binding**: Immediate
- **Reclaim Policy**: Delete
- **Expansion**: Enabled (can grow without downtime)

**PVCs**:
- `postgresql-sg3-pgvector-1`: 20Gi on vps51
- `postgresql-sg3-pgvector-2`: 20Gi on vps57
- `postgresql-sg3-pgvector-3`: 20Gi on vps54

## Services

**Kubernetes Services**:
- `postgresql-sg3-pgvector-rw`: Read-write endpoint (points to primary)
- `postgresql-sg3-pgvector-r`: Read-only endpoint (all replicas)
- `postgresql-sg3-pgvector-ro`: Read-only endpoint (excludes primary)

**Internal DNS**:
```
postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local:5432
```

## Access Information

### Users
- **postgres**: Superuser (administrative access)
- **app**: Application user (read/write on app database)

### Databases
- **app**: Main application database (owner: app)

### Connection String
```bash
# Read-Write (primary)
postgresql://app:<password>@postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local:5432/app

# Read-Only (replicas)
postgresql://app:<password>@postgresql-sg3-pgvector-r.postgres-db.svc.cluster.local:5432/app
```

### Get Credentials
```bash
# App user password
kubectl get secret app-sg3-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d

# Superuser password
kubectl get secret superuser-sg3-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d
```

## pgvector Usage

### Extension Info
- **Name**: vector
- **Version**: 0.8.0
- **Description**: vector data type and ivfflat and hnsw access methods

### Example Usage

```sql
-- Create table with vector embeddings
CREATE TABLE documents (
  id serial PRIMARY KEY,
  title text,
  content text,
  embedding vector(1536)  -- For OpenAI embeddings
);

-- Insert documents with embeddings
INSERT INTO documents (title, content, embedding) VALUES
  ('Doc 1', 'Content...', '[0.1, 0.2, ...]');

-- Semantic search (L2 distance)
SELECT id, title, embedding <-> $1 AS distance
FROM documents
ORDER BY distance
LIMIT 10;

-- Cosine similarity search
SELECT id, title, 1 - (embedding <=> $1) AS similarity
FROM documents
ORDER BY similarity DESC
LIMIT 10;

-- Create index for performance
CREATE INDEX ON documents USING ivfflat (embedding vector_l2_ops);
-- or
CREATE INDEX ON documents USING hnsw (embedding vector_l2_ops);
```

### Distance Operators
- `<->`: L2 (Euclidean) distance
- `<=>`: Cosine distance (1 - cosine similarity)
- `<#>`: Inner product distance

## TimescaleDB Usage

### Extension Info
- **Name**: timescaledb
- **Shared Preload**: Loaded via `shared_preload_libraries`
- **Telemetry**: Disabled (`timescaledb.telemetry_level: off`)
- **Background Workers**: 8 (`timescaledb.max_background_workers: 8`)

### Example Usage

```sql
-- Create a time-series table
CREATE TABLE sensor_data (
  time TIMESTAMPTZ NOT NULL,
  device_id TEXT NOT NULL,
  value DOUBLE PRECISION
);

-- Convert to hypertable (automatic time-based partitioning)
SELECT create_hypertable('sensor_data', 'time');

-- Insert data
INSERT INTO sensor_data (time, device_id, value)
VALUES (NOW(), 'device-1', 42.5);

-- Time-bucket aggregation (e.g., hourly averages)
SELECT time_bucket('1 hour', time) AS bucket,
       device_id,
       AVG(value) AS avg_value
FROM sensor_data
WHERE time > NOW() - INTERVAL '24 hours'
GROUP BY bucket, device_id
ORDER BY bucket DESC;

-- Continuous aggregate (materialized view with auto-refresh)
CREATE MATERIALIZED VIEW hourly_averages
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
       device_id,
       AVG(value) AS avg_value,
       COUNT(*) AS sample_count
FROM sensor_data
GROUP BY bucket, device_id;

-- Add refresh policy
SELECT add_continuous_aggregate_policy('hourly_averages',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour');

-- Compression policy (compress chunks older than 7 days)
ALTER TABLE sensor_data SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id'
);
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');

-- Retention policy (drop data older than 90 days)
SELECT add_retention_policy('sensor_data', INTERVAL '90 days');
```

### Verify TimescaleDB
```bash
kubectl exec postgresql-sg3-pgvector-1 -n postgres-db -- \
  psql -U postgres -d app -c "\dx timescaledb"

# Check shared_preload_libraries
kubectl exec postgresql-sg3-pgvector-1 -n postgres-db -- \
  psql -U postgres -c "SHOW shared_preload_libraries;"
```

## Monitoring

### Prometheus
- **ScrapeConfig**: `postgresql-sg3-pgvector` in monitoring namespace
- **Metrics Port**: 9187
- **Scrape Interval**: 30s
- **Targets**: All 3 PostgreSQL pods

### Grafana Dashboards
Two dashboards automatically imported via ConfigMaps:

1. **CloudNativePG Dashboard**
   - Cluster health overview
   - Replication status
   - Resource utilization
   - Backup monitoring

2. **PostgreSQL Database Dashboard**
   - Database metrics
   - Table statistics
   - Cache hit ratios
   - Transaction rates

**Access**: https://grafana.sg3.k3s.canhnv.com → Dashboards → Search for "PostgreSQL" or "CNPG"

### Alert Rules

**Critical Alerts**:
- PostgreSQLInstanceDown (2m threshold)
- PostgreSQLClusterDown (1m threshold)

**Warning Alerts**:
- PostgreSQLHighConnections (>80% for 5m)
- PostgreSQLReplicationLag (>1GB for 5m)
- PostgreSQLDatabaseGrowth (rapid growth detection)

## Operations

### Check Cluster Status
```bash
# Switch to sg3 context
kubectl config use-context sg3

# Check cluster health
kubectl get clusters.postgresql.cnpg.io -n postgres-db

# Check pods
kubectl get pods -n postgres-db

# Check services
kubectl get svc -n postgres-db
```

### Connect to Database
```bash
# Connect as postgres superuser
kubectl exec -it postgresql-sg3-pgvector-1 -n postgres-db -- psql -U postgres

# Connect as app user
kubectl exec -it postgresql-sg3-pgvector-1 -n postgres-db -- psql -U app -d app
```

### Check Replication Status
```bash
kubectl exec postgresql-sg3-pgvector-1 -n postgres-db -- \
  psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
```

### View Logs
```bash
# Cluster logs
kubectl logs -n postgres-db postgresql-sg3-pgvector-1 -f

# Operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -f
```

### Verify pgvector
```bash
kubectl exec postgresql-sg3-pgvector-1 -n postgres-db -- \
  psql -U postgres -d app -c "\dx vector"
```

## Files

### Configuration Files
- `cluster-sg3-pgvector.yaml` - PostgreSQL cluster configuration
- `secrets-sg3.yaml` - User passwords (DO NOT COMMIT - contains sensitive data)
- `prometheus-scrapeconfig.yaml` - Prometheus scraping configuration
- `prometheus-alerts.yaml` - Alert rules
- `grafana-dashboard-cnpg.yaml` - CloudNativePG Grafana dashboard (284KB)
- `grafana-dashboard-postgresql-db.yaml` - PostgreSQL database dashboard (83KB)

### Deployment
```bash
# Apply all configurations (except secrets - handle separately)
kubectl apply -f cluster-sg3-pgvector.yaml
kubectl apply -f prometheus-scrapeconfig.yaml
kubectl apply -f prometheus-alerts.yaml
kubectl create -f grafana-dashboard-cnpg.yaml --save-config=false
kubectl create -f grafana-dashboard-postgresql-db.yaml --save-config=false
```

## Troubleshooting

### Cluster Not Ready
```bash
kubectl describe cluster postgresql-sg3-pgvector -n postgres-db
kubectl logs -n postgres-db postgresql-sg3-pgvector-1
```

### Replication Issues
```bash
kubectl exec postgresql-sg3-pgvector-1 -n postgres-db -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### Longhorn Volume Issues
```bash
# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system | grep postgresql-sg3

# Check volume health in Longhorn UI
# https://sg3.longhorn.canhnv.com
```

### Monitoring Not Working
```bash
# Check ScrapeConfig
kubectl get scrapeconfig -n monitoring postgresql-sg3-pgvector

# Check PrometheusRule
kubectl get prometheusrule -n monitoring postgresql-sg3-alerts

# Verify metrics endpoint
kubectl port-forward -n postgres-db postgresql-sg3-pgvector-1 9187:9187
# Then: curl localhost:9187/metrics
```

## Known Issues

### Longhorn Volume Formatting
During initial deployment, Longhorn volumes may encounter "mke2fs: device is apparently in use" errors.

**Solution**:
1. Restart Longhorn CSI components
2. Force delete and recreate failed pods
3. Restart Longhorn manager on affected nodes

This was resolved during deployment but may occur on future redeployments.

## Success Criteria

- ✅ 3 PostgreSQL pods running and healthy
- ✅ All PVCs using Longhorn storage class
- ✅ Replication lag < 1 second
- ✅ pgvector extension operational
- ✅ TimescaleDB extension operational
- ✅ Prometheus scraping metrics
- ✅ Grafana dashboards available
- ✅ Alert rules configured

## Next Steps

1. **Monitor Volume Health**: Check Longhorn UI to ensure all replicas are healthy
2. **Import Dashboards**: Refresh Grafana to see new PostgreSQL dashboards
3. **Configure Backups**: Add WAL archiving to MinIO for disaster recovery (optional)
4. **Add Users**: Create additional database users as needed
5. **Scale Instances**: Can scale to 5 instances for higher availability if needed

## Support

For issues or questions, refer to:
- CloudNativePG documentation: https://cloudnative-pg.io/
- pgvector documentation: https://github.com/pgvector/pgvector
- TimescaleDB documentation: https://docs.timescale.com/
- Longhorn documentation: https://longhorn.io/docs/
