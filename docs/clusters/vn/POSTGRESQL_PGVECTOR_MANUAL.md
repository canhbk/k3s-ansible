# PostgreSQL pgvector Manual Deployment - VN Cluster

**Last Updated**: 2025-12-08

## Overview

The PostgreSQL pgvector instance on the VN cluster is currently running as a **manual StatefulSet** instead of a CloudNative-PG managed cluster due to disk space constraints that prevented the CNPG operator from managing the lifecycle properly.

## Current Configuration

### Deployment Method

- **Type**: Manual StatefulSet (not CloudNative-PG managed)
- **Namespace**: postgres-db
- **StatefulSet**: postgresql-pgvector
- **Replicas**: 1
- **Image**: `pgvector/pgvector:0.8.0-pg17`
- **Storage**: 4Gi PVC (longhorn-vn storage class)
- **Node**: Distributed across Longhorn-enabled nodes

### Service Endpoints

- **Service Name**: postgresql-pgvector-rw
- **Type**: ClusterIP (Headless)
- **Port**: 5432
- **Internal DNS**: `postgresql-pgvector-rw.postgres-db.svc.cluster.local:5432`

### Database Configuration

**Databases**:
- `murror-ai` (owner: dev, user: ai)
- `default` (owner: dev)

**Users**:
- `postgres` (superuser)
- `ai` (murror-ai database access)
- `dev` (default database owner)

**Extensions**:
- pgvector (installed in murror-ai database)

## Access Information

### Internal Access (from within cluster)

```bash
# Connection string for murror-ai application
postgresql://ai:***@postgresql-pgvector-rw.postgres-db.svc.cluster.local:5432/murror-ai
```

### Admin Access

```bash
# Connect as superuser from within cluster
kubectl exec -it postgresql-pgvector-0 -n postgres-db -- psql -U postgres

# List databases
kubectl exec postgresql-pgvector-0 -n postgres-db -- psql -U postgres -c "\l"

# List users
kubectl exec postgresql-pgvector-0 -n postgres-db -- psql -U postgres -c "\du"
```

## Security Configuration

### pg_hba.conf Rules

The following rules allow connections from the Kubernetes pod network:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    all             all             10.42.0.0/16            md5   # Pod network
```

**Note**: pg_hba.conf is NOT persistent across pod restarts. After any pod deletion, the rule must be re-added:

```bash
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  sh -c 'echo "host all all 10.42.0.0/16 md5" >> /var/lib/postgresql/data/pgdata/pg_hba.conf'

kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  psql -U postgres -c "SELECT pg_reload_conf();"
```

## Incident History

### 2025-12-08: Disk Space Exhaustion & Recovery

**Issue**: PostgreSQL pgvector pod in CrashLoopBackOff, murror-ai pods unable to connect

**Root Cause**:
- 4Gi PVC filled to 100% capacity
- CloudNative-PG refused to start due to insufficient disk space
- WAL files accumulated (912MB)

**Resolution Steps**:

1. **Cleaned up WAL files**: Freed 600MB by removing old WAL files and archive status
2. **Expanded Longhorn infrastructure**: Added longhorn labels to 3 additional nodes (vps22, vps23, vps24)
3. **Migrated to manual StatefulSet**: Due to CNPG reconciliation issues, deployed PostgreSQL as manual StatefulSet
4. **Restored data**: Used CloudNative-PG backup directory `pgdata_20251208T084231Z`
5. **Recreated database and users**: Created `murror-ai` database and `ai` user
6. **Fixed network access**: Added pg_hba.conf rule for pod network (10.42.0.0/16)

**Outcome**:
- ✅ PostgreSQL running and healthy
- ✅ All 3 murror-ai API pods READY (1/1)
- ✅ Health checks passing (200 OK)
- ✅ Supabase connectivity verified (already working)

## Storage Architecture

### Longhorn Configuration

**Nodes with Longhorn storage** (4 total):
- vps22-vnix (14.225.210.108) - 45GB available
- vps23-vnix (14.225.210.165) - 45GB available
- vps24-vnix (14.225.210.170) - 45GB available
- vps33-vnix-nvme-dedicated-cpu (14.225.210.189) - 45GB available

**Volume Replication**:
- Default replica count: 3
- Volumes distributed across multiple nodes for high availability
- Storage class: longhorn-vn (retain policy)

**Current Volumes on VN**:
- postgresql-ha-1: 5Gi (1 replica → 3 replicas)
- postgresql-pgvector-1: 4Gi (1 replica → 3 replicas)
- influxdb-influxdb2: 20Gi (1 replica → 3 replicas)
- redis-data: 2Gi (1 replica → 3 replicas)
- rabbitmq-0: 2Gi (1 replica → 3 replicas)

## Limitations & Known Issues

### 1. Not Managed by CloudNative-PG

**Implications**:
- No automatic backup/WAL archiving
- No automatic failover or self-healing
- Manual user/database management required
- pg_hba.conf changes not persistent

**Workarounds**:
- Regular manual backups via pg_dump
- Monitor disk usage manually
- Document all manual configuration changes

### 2. Storage Constraints

**Current**: 4Gi PVC at 84% usage (3.2G / 3.9G)

**Future Expansion Blocked**: Cannot expand beyond 4Gi on current node infrastructure due to overall disk capacity

**Mitigation**:
- Aggressive WAL file cleanup (manual)
- Consider migrating to a larger disk node
- OR implement external WAL archiving to MinIO

### 3. pg_hba.conf Not Persistent

After pod restart, must re-run:
```bash
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  sh -c 'echo "host all all 10.42.0.0/16 md5" >> /var/lib/postgresql/data/pgdata/pg_hba.conf'
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  psql -U postgres -c "SELECT pg_reload_conf();"
```

## Monitoring

### Health Checks

```bash
# Check PostgreSQL pod
kubectl get pods -n postgres-db -l app=postgresql-pgvector

# Check murror-ai connectivity
kubectl get pods -n nsp-prod-murror-ai | grep murror-ai

# Check service endpoints
kubectl get endpoints murror-ai -n nsp-prod-murror-ai

# Test database connection
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  psql -U ai -d murror-ai -c "SELECT version();"
```

### Disk Usage Monitoring

```bash
# Check PVC usage
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  df -h /var/lib/postgresql/data

# Check WAL directory size
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  du -sh /var/lib/postgresql/data/pgdata/pg_wal
```

## Backup & Recovery

### Manual Backup

```bash
# Backup murror-ai database
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  pg_dump -U ai murror-ai > murror-ai-backup-$(date +%Y%m%d).sql

# Backup all databases
kubectl exec postgresql-pgvector-0 -n postgres-db -- \
  pg_dumpall -U postgres > all-databases-backup-$(date +%Y%m%d).sql
```

### Data Recovery

CloudNative-PG creates backup directories before operations:
- `/var/lib/postgresql/data/pgdata_YYYYMMDDTHHMMSSZ`

To restore from a backup directory:
1. Scale StatefulSet to 0
2. Run restore job (see `/tmp/restore-data-job.yaml` for template)
3. Scale StatefulSet back to 1
4. Re-add pg_hba.conf rules

## Future Improvements

1. **Migrate back to CloudNative-PG**: When disk space is resolved
2. **Implement external WAL archiving**: To MinIO or S3-compatible storage
3. **Add automated pg_hba.conf**: Use ConfigMap mounted as file
4. **Increase storage**: Expand to 20Gi when node capacity allows
5. **Set up monitoring alerts**: For disk usage > 80%

## Migration Path Back to CloudNative-PG

When ready to migrate back to CNPG management:

1. Create full backup of current data
2. Increase PVC size or add more Longhorn storage
3. Delete manual StatefulSet
4. Restore original cluster configuration with initdb bootstrap
5. Apply CNPG cluster resource
6. Verify cluster health and restore data if needed

## Related Files

- **StatefulSet**: `/tmp/postgresql-manual-statefulset.yaml`
- **Original CNPG Config**: `/database/postgresql/clusters/vn/cluster-pgvector.yaml`
- **Secrets**: `/database/postgresql/clusters/vn/secrets-pgvector.yaml`
- **LoadBalancer**: `/database/postgresql/clusters/vn/postgres-murror-ai-loadbalancer.yaml`

## Support

For issues or questions, check:
- PostgreSQL logs: `kubectl logs postgresql-pgvector-0 -n postgres-db`
- murror-ai logs: `kubectl logs -n nsp-prod-murror-ai <pod-name>`
- Longhorn UI: Access via Longhorn dashboard
