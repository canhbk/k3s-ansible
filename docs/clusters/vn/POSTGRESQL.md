# PostgreSQL on VN Cluster

## Overview

PostgreSQL is deployed on the VN cluster with two separate instances:

1. **postgresql-ha**: Standard PostgreSQL 17 HA cluster (CloudNative-PG managed)
2. **postgresql-pgvector**: PostgreSQL 17 with pgvector extension (**Manual StatefulSet** - see note below)

**IMPORTANT**: The postgresql-pgvector instance is currently running as a manual StatefulSet due to disk space issues. See [POSTGRESQL_PGVECTOR_MANUAL.md](./POSTGRESQL_PGVECTOR_MANUAL.md) for details.

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

### postgresql-pgvector

- **PVC**: `postgresql-pgvector-1`
- **Size**: 20Gi (expanded from 4Gi on 2025-12-11)
- **Storage Class**: `longhorn-vn`
- **Status**: Healthy
- **Node**: vps22-vnix (migrated from vps33)

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

## Last Updated

- Date: 2025-12-15
- Service Type: NodePort
- NodePort: 30432
- Backup: Cloudflare R2 (Hourly, 30-day retention)
- Storage: postgresql-pgvector PVC expanded to 20Gi
- Monitoring: Prometheus alerts with Slack notifications
