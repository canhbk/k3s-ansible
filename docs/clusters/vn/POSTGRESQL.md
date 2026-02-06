# PostgreSQL on VN Cluster

## Overview

PostgreSQL is deployed on the VN cluster with three instances:

1. **postgresql-ha**: Standard PostgreSQL 17 HA cluster (CloudNative-PG managed)
2. **postgresql-pgvector-cnpg**: PostgreSQL 17 with pgvector extension (CloudNative-PG managed, R2 backup enabled)
3. **postgresql-pgvector**: PostgreSQL 17 with pgvector extension (**Manual StatefulSet** - legacy, kept for rollback)

**NOTE**: As of 2026-02-06, murror-ai has been migrated from `postgresql-pgvector` (manual StatefulSet) to `postgresql-pgvector-cnpg` (CNPG-managed). The manual StatefulSet is kept running for rollback purposes. See [POSTGRESQL_PGVECTOR_MANUAL.md](./POSTGRESQL_PGVECTOR_MANUAL.md) for the manual StatefulSet details.

## Internal Access

The PostgreSQL service is available internally at:
- **Service**: `postgresql-ha-rw.postgres-db`
- **Port**: 5432
- **Connection String**: `postgresql://be:***@postgresql-ha-rw.postgres-db:5432/murror`

## External Access

PostgreSQL is exposed to the internet via NodePort service.

### Connection Details

- **External IPs**: 
  - 14.225.210.108:30432
  - 14.225.210.165:30432
  - 14.225.210.170:30432
  - 14.225.210.189:30432
- **Port**: 30432
- **Database**: murror
- **Username**: be

### External Connection String

```
postgresql://be:***@14.225.210.108:30432/murror
```

You can use any of the external IPs listed above. The primary instance is currently running on node `vps33-vnix-nvme-dedicated-cpu` (14.225.210.189).

### Service Configuration

The external access is configured via NodePort service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-ha-external
  namespace: postgres-db
  labels:
    cnpg.io/cluster: postgresql-ha
    service.type: external-access
spec:
  type: NodePort
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
    protocol: TCP
    nodePort: 30432
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  sessionAffinity: None
```

## Security Considerations

⚠️ **WARNING**: The PostgreSQL database is now exposed to the internet. Ensure you:

1. **Use strong passwords** - The current password should be rotated regularly
2. **Implement firewall rules** - Consider restricting access to specific IP addresses
3. **Enable SSL/TLS** - Configure PostgreSQL to require encrypted connections
4. **Monitor access logs** - Check for unauthorized access attempts
5. **Regular backups** - Ensure automated backups are configured

## Verification

To verify external connectivity:

```bash
# Test connection from outside the cluster
psql "postgresql://be:***@14.225.210.108:30432/murror" -c "SELECT version();"

# Check service status
kubectl get svc -n postgres-db postgresql-ha-external

# Check primary pod
kubectl get pods -n postgres-db -l cnpg.io/instanceRole=primary
```

## Backup & Recovery

### Cloudflare R2 Backup Configuration

PostgreSQL HA cluster is configured with automated backups to Cloudflare R2:

- **Provider**: Cloudflare R2
- **Bucket**: `murror-api-prod-postgres-backup`
- **Path**: `s3://murror-api-prod-postgres-backup/postgresql-ha-vn/`
- **Schedule**: Hourly (at minute 0 of every hour)
- **Retention**: 30 days
- **WAL Archiving**: Enabled with gzip compression
- **First Recovery Point**: 2025-12-08T09:30:06Z

### PostgreSQL pgvector CNPG Backup Configuration

The pgvector CNPG cluster also has automated backups to Cloudflare R2 via the Barman Cloud Plugin:

- **Provider**: Cloudflare R2 (via Barman Cloud Plugin sidecar)
- **Bucket**: `murror-api-prod-postgres-backup`
- **Path**: `s3://murror-api-prod-postgres-backup/postgresql-pgvector-cnpg-vn/`
- **Schedule**: Every 6 hours (at 00:00, 06:00, 12:00, 18:00 UTC)
- **Retention**: 30 days
- **WAL Archiving**: Enabled with gzip compression (via barman-cloud sidecar)
- **Image**: `pgvector/pgvector:0.8.1-pg17` (pgvector v0.8.1)
- **Plugin**: `barman-cloud.cloudnative-pg.io` v0.6.0

**Note**: Unlike postgresql-ha which uses the built-in barman-cloud tools in the CNPG standard image, the pgvector cluster uses the Barman Cloud Plugin (sidecar injection) because the `pgvector/pgvector` image doesn't include barman-cloud tools. The cluster's `postgresUID: 999` is immutable and prevents switching to the standard CNPG image (which uses UID 26).

#### Manifest Files

- `database/postgresql/clusters/vn/cluster-pgvector-cnpg.yaml` — Cluster definition with plugin config
- `database/postgresql/clusters/vn/objectstore-pgvector-cnpg.yaml` — ObjectStore CRD for R2 backup
- `database/postgresql/clusters/vn/scheduled-backup-pgvector-cnpg-hourly.yaml` — ScheduledBackup (6-hourly)

### Backup Status

```bash
# Check scheduled backup
kubectl get scheduledbackup -n postgres-db

# Check backup history
kubectl get backup -n postgres-db --sort-by=.metadata.creationTimestamp

# Check cluster recovery point
kubectl get cluster postgresql-ha -n postgres-db -o jsonpath='{.status.firstRecoverabilityPoint}'

# View WAL archiving logs
kubectl logs postgresql-ha-1 -n postgres-db -c postgres | grep "Archived WAL file"
```

### Recovery Procedures

Point-in-time recovery and restore procedures are documented in [POSTGRESQL_BACKUP_RESTORE.md](./POSTGRESQL_BACKUP_RESTORE.md).

### Cross-Cluster Restore Verification

On 2025-12-08, the VN cluster backup was successfully restored to the EU cluster, verifying that the Cloudflare R2 backup system works for disaster recovery scenarios. See [EU Cluster PostgreSQL](../eu/POSTGRESQL.md) for details.

---

## Storage Configuration

### postgresql-ha

- **PVC**: `postgresql-ha-1`
- **Size**: 5Gi
- **Storage Class**: `longhorn-vn`
- **Status**: Healthy

### postgresql-pgvector-cnpg (CNPG-managed, active)

- **PVC**: `postgresql-pgvector-cnpg-1`
- **Size**: 20Gi
- **Storage Class**: `longhorn-vn`
- **Status**: Healthy, backup enabled
- **Database Size**: ~1.3GB (murror-ai)
- **Connection**: `postgresql-pgvector-cnpg-rw.postgres-db:5432`
- **Used by**: murror-ai (nsp-prod-murror-ai namespace)

### postgresql-pgvector (Manual StatefulSet, legacy)

- **PVC**: `postgresql-pgvector-1`
- **Size**: 20Gi (expanded from 4Gi on 2025-12-11)
- **Storage Class**: `longhorn-vn`
- **Status**: Running but no longer serving applications
- **Note**: Kept for rollback. Will be decommissioned after extended verification.

## Monitoring & Alerting

PostgreSQL is monitored via Prometheus with alerts sent to Slack.

### Slack Channel

- **Channel**: `#alert-production-database`

### Active Alerts

| Alert | Threshold | Severity | Duration |
|-------|-----------|----------|----------|
| PostgreSQLStorageWarning | PVC >80% | warning | 1m |
| PostgreSQLPgVectorStorageWarning | PVC >80% | warning | 1m |
| PostgreSQLStorageCritical | PVC >90% | critical | 2m |
| PostgreSQLHAStorageWarning | DB >4GB (80% of 5GB) | warning | 5m |
| PostgreSQLHAStorageCritical | DB >4.5GB (90% of 5GB) | critical | 2m |
| PostgreSQLPodDown | Pod down | critical | 2m |
| PostgreSQLNotReady | Pod not ready | warning | 5m |

### Alert Files

- `database/postgresql/clusters/vn/prometheus-alerts.yaml` - PVC-based storage alerts
- `database/postgresql/clusters/vn/prometheus-alerts-simple.yaml` - Health alerts
- `database/postgresql/clusters/vn/prometheus-alerts-storage.yaml` - CNPG database size alerts

### Grafana Dashboard

Access via: `https://grafana.vn.k3s.canhnv.com`

## Incident History

### 2026-01-22: PostgreSQL pgvector Storage Investigation and WAL Cleanup

**Issue**: Disk usage at 61% (12GB/20GB) with alert potential for storage pressure.

**Root Cause**:
- Archive mode was enabled (`archive_mode=on`) but `archive_command` was empty
- This caused PostgreSQL to retain ALL WAL files indefinitely
- 474 WAL files accumulated since December 8th, consuming 7.4GB

**Resolution**:
1. Disabled archive mode by adding `-c archive_mode=off` to PostgreSQL startup command
2. Forced checkpoint to trigger WAL cleanup: `CHECKPOINT;`
3. Executed `VACUUM ANALYZE` to optimize database

**Results**:
- WAL files reduced: 474 → 39 files
- WAL directory size: 7.4GB → 593MB
- Total disk usage: 12GB → 5.1GB (61% → 26%)
- No PVC expansion needed - current 20Gi provides adequate headroom

**Prevention**: Archive mode now properly disabled. WAL retention controlled by `max_wal_size` (1GB) and `wal_keep_size` (512MB).

### 2026-02-06: pgvector Database Migration to CNPG with R2 Backup

**Issue**: The pgvector database (`postgresql-pgvector`, manual StatefulSet) had no backup configured, posing data loss risk for ~1.2GB of murror-ai data.

**Solution**:
1. Updated existing CNPG cluster (`postgresql-pgvector-cnpg`) with Barman Cloud Plugin for R2 backup
2. Created ObjectStore CRD and ScheduledBackup (every 6 hours, 30-day retention)
3. Migrated murror-ai data from manual StatefulSet to CNPG cluster via pg_dump/pg_restore
4. Switched murror-ai connection from `postgresql-pgvector-rw` to `postgresql-pgvector-cnpg-rw`

**Key technical decisions**:
- Used `pgvector/pgvector:0.8.1-pg17` image (not CNPG standard) due to immutable `postgresUID: 999`
- Used Barman Cloud Plugin (sidecar) for backup since pgvector image lacks barman-cloud tools
- Manual StatefulSet kept running for rollback safety

**Results**:
- WAL archiving: Continuous archiving working
- Scheduled backups: Every 6 hours to R2
- Data integrity: All records verified matching between source and target
- murror-ai: Successfully serving from CNPG cluster

## Last Updated

- Date: 2026-02-06
- Service Type: NodePort
- NodePort: 30432
- Backup (postgresql-ha): Cloudflare R2 (Hourly, 30-day retention)
- Backup (postgresql-pgvector-cnpg): Cloudflare R2 via Barman Cloud Plugin (Every 6 hours, 30-day retention)
- murror-ai connection: `postgresql-pgvector-cnpg-rw.postgres-db:5432/murror-ai`
- Monitoring: Prometheus alerts with Slack notifications
