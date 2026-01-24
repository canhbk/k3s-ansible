# PostgreSQL on US Cluster

## Overview

PostgreSQL master database deployed on the US cluster using CloudNative-PG (CNPG) operator.

**Deployment Date**: 2025-11-04
**Last Updated**: 2025-11-04

## Cluster Information

### postgresql-us-master

- **Type**: Master (standalone, no replication)
- **Version**: PostgreSQL 17.2
- **Image**: `ghcr.io/cloudnative-pg/postgresql:17.2`
- **Instances**: 1 (single instance, no HA)
- **Namespace**: `postgres-db`
- **Storage**: 5Gi (Longhorn replicated)
- **Backup**: MinIO S3 (configured, requires bucket setup)

## Architecture

```
┌─────────────────────────────────────┐
│   US Cluster (Kubernetes)          │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  postgresql-us-master        │   │
│  │  Namespace: postgres-db      │   │
│  │                              │   │
│  │  ┌────────────────────────┐  │   │
│  │  │ postgresql-us-master-1 │  │   │
│  │  │ (Primary Instance)     │  │   │
│  │  │ - PostgreSQL 17.2      │  │   │
│  │  │ - Storage: 5Gi         │  │   │
│  │  │ - Resources: 512Mi-2Gi │  │   │
│  │  └────────────────────────┘  │   │
│  │                              │   │
│  │  Services:                   │   │
│  │  - postgresql-us-master-rw   │   │
│  │  - postgresql-us-master-ro   │   │
│  │  - postgresql-us-master-r    │   │
│  └──────────────────────────────┘   │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  MinIO (S3-compatible)       │   │
│  │  Namespace: minio            │   │
│  │                              │   │
│  │  WAL Backup: s3://postgres-  │   │
│  │              wal/us-master   │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Services

### Internal Services (ClusterIP)

1. **postgresql-us-master-rw** (Read-Write)
   - ClusterIP: `10.47.11.103`
   - Port: `5432`
   - Purpose: Primary instance access (read/write operations)

2. **postgresql-us-master-ro** (Read-Only)
   - ClusterIP: `10.47.4.64`
   - Port: `5432`
   - Purpose: Read-only access (with single instance, same as rw)

3. **postgresql-us-master-r** (Read)
   - ClusterIP: `10.47.163.120`
   - Port: `5432`
   - Purpose: Read operations

## Databases

### murror-be

- **Owner**: `be` user
- **Purpose**: Backend application database
- **Created**: 2025-11-04

## Users and Roles

### Superuser

- **Username**: `postgres`
- **Secret**: `superuser-us-master-secret` (namespace: `postgres-db`)
- **Password**: Auto-generated (base64 encoded)

### Application Users

1. **be (Backend)**
   - **Secret**: `be-us-master-secret`
   - **Password**: Auto-generated
   - **Databases**: `murror-be`
   - **Privileges**: Owner of `murror-be` database

## Connection Information

### From Within Cluster

**Read-Write Connection**:
```
Host: postgresql-us-master-rw.postgres-db.svc.cluster.local
Port: 5432
Database: murror-be
User: be
Password: <from secret be-us-master-secret>
```

**Connection String**:
```
postgresql://be:PASSWORD@postgresql-us-master-rw.postgres-db.svc.cluster.local:5432/murror-be
```

**Read-Only Connection**:
```
Host: postgresql-us-master-ro.postgres-db.svc.cluster.local
Port: 5432
Database: murror-be
User: be
Password: <from secret be-us-master-secret>
```

### Connection Examples

#### Using psql
```bash
# Get the password
kubectl get secret be-us-master-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d

# Connect from within the cluster
kubectl run -it --rm psql \
  --image=postgres:17 \
  --restart=Never \
  --namespace=postgres-db \
  -- psql "postgresql://be:PASSWORD@postgresql-us-master-rw.postgres-db.svc.cluster.local:5432/murror-be"
```

#### Using kubectl port-forward
```bash
# Forward the port
kubectl port-forward -n postgres-db svc/postgresql-us-master-rw 5432:5432

# Connect from your local machine
psql "postgresql://be:PASSWORD@localhost:5432/murror-be"
```

## Backup Configuration

### MinIO S3 Storage

- **Endpoint**: `http://minio-internal.minio.svc.cluster.local:9000`
- **Bucket**: `postgres-wal`
- **Path**: `s3://postgres-wal/us-master`
- **Retention**: 7 days
- **Compression**: gzip

### Credentials

- **Secret**: `postgresql-minio-credentials` (namespace: `postgres-db`)
- **Access Key**: `MINIO_ACCESS_KEY`
- **Secret Key**: `MINIO_SECRET_KEY`

### Current Status

⚠️ **Note**: WAL archiving is currently failing with 403 Forbidden error. The bucket `postgres-wal/us-master` needs to be created in MinIO or the credentials need proper permissions.

**To fix**:
1. Access MinIO console: `http://64.71.161.44:9090`
2. Create bucket `postgres-wal` if it doesn't exist
3. Create folder `us-master` within the bucket
4. Verify credentials have read/write access

## Monitoring

### Check Cluster Status

```bash
# Switch to US cluster context
kubectl config use-context us

# Check cluster status
kubectl get cluster -n postgres-db

# Detailed status
kubectl cnpg status postgresql-us-master -n postgres-db

# Check pods
kubectl get pods -n postgres-db | grep postgresql-us-master

# Check services
kubectl get svc -n postgres-db | grep postgresql-us-master
```

### Check Logs

```bash
# PostgreSQL logs
kubectl logs -n postgres-db postgresql-us-master-1 -c postgres --tail=100

# Follow logs
kubectl logs -n postgres-db postgresql-us-master-1 -c postgres -f
```

### Check Backups

```bash
# Check backup status
kubectl cnpg status postgresql-us-master -n postgres-db | grep -A10 "Continuous Backup"

# Check WAL archiving
kubectl logs -n postgres-db postgresql-us-master-1 | grep -i "barman\|archive"
```

## Operations

### Get Credentials

```bash
# Superuser password
kubectl get secret superuser-us-master-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d && echo

# BE user password
kubectl get secret be-us-master-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d && echo
```

### Connect to Database

```bash
# Using superuser
kubectl exec -it postgresql-us-master-1 -n postgres-db -- psql -U postgres

# Using be user
kubectl exec -it postgresql-us-master-1 -n postgres-db -- psql -U be -d murror-be
```

### Create Additional Database

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: my-new-database
  namespace: postgres-db
spec:
  name: my_database_name
  owner: be
  cluster:
    name: postgresql-us-master
```

### Scale to HA (3 instances)

```bash
kubectl patch cluster postgresql-us-master -n postgres-db \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/instances", "value": 3}]'
```

## Configuration Files

### Cluster Manifest

`database/postgresql/clusters/us/cluster-us-master-pgvector.yaml`

### Secrets

`database/postgresql/clusters/us/secrets-us-master.yaml`

⚠️ **Warning**: Secrets file contains sensitive data and should not be committed to version control with real passwords.

## Resource Limits

### Per Instance

- **CPU Request**: 100m
- **CPU Limit**: 1000m (1 core)
- **Memory Request**: 512Mi
- **Memory Limit**: 2Gi

### Storage

- **Size**: 5Gi
- **Storage Class**: `longhorn-replicated`
- **Volume**: Persistent, survives pod restarts

## PostgreSQL Configuration

### Key Parameters

```yaml
max_wal_senders: "5"
wal_keep_size: "512MB"
max_replication_slots: "5"
archive_timeout: "5min"
shared_buffers: "256MB"
effective_cache_size: "1GB"
maintenance_work_mem: "64MB"
work_mem: "4MB"
max_connections: "100"
log_min_duration_statement: "1000"  # Log queries > 1s
log_checkpoints: "on"
log_connections: "on"
log_disconnections: "on"
```

## Security

### Access Control

- **Namespace Isolation**: All resources in `postgres-db` namespace
- **Network Policy**: Only ClusterIP services (no external access)
- **TLS**: Not configured (internal only)
- **Authentication**: Password-based via Kubernetes secrets

### Secrets Management

All passwords are stored in Kubernetes secrets:
- `superuser-us-master-secret` - PostgreSQL superuser
- `be-us-master-secret` - Backend application user
- `postgresql-minio-credentials` - MinIO backup credentials

## Troubleshooting

### Cluster Not Starting

```bash
# Check cluster events
kubectl describe cluster postgresql-us-master -n postgres-db

# Check pod events
kubectl describe pod postgresql-us-master-1 -n postgres-db

# Check init container logs
kubectl logs postgresql-us-master-1-initdb -n postgres-db
```

### Connection Issues

```bash
# Test from within cluster
kubectl run -it --rm debug \
  --image=postgres:17 \
  --restart=Never \
  --namespace=postgres-db \
  -- psql "postgresql://be:PASSWORD@postgresql-us-master-rw:5432/murror-be" -c "SELECT version();"
```

### Backup Issues

```bash
# Check WAL archiving errors
kubectl logs postgresql-us-master-1 -n postgres-db | grep -i "archive\|barman" | tail -20

# Check MinIO accessibility
kubectl exec -it postgresql-us-master-1 -n postgres-db -- \
  curl -v http://minio-internal.minio.svc.cluster.local:9000
```

## Future Enhancements

### Potential Improvements

1. **High Availability**: Scale to 3 instances for automatic failover
2. **pgvector Extension**: Add support for vector embeddings (requires different image)
3. **Backup Verification**: Set up automated backup testing
4. **External Access**: Add LoadBalancer service if needed for external tools
5. **Monitoring**: Integrate with Prometheus/Grafana
6. **Read Replicas**: Add in different regions for better performance

### Adding pgvector Support

To add pgvector extension support:

1. Change image to `pgvector/pgvector:0.8.0-pg17`
2. Add `postInitSQL: CREATE EXTENSION IF NOT EXISTS pgvector;`
3. Note: This requires re-deploying the cluster (downtime)

## Support

### Common Commands

```bash
# Check cluster health
kubectl cnpg status postgresql-us-master -n postgres-db

# Restart cluster (careful!)
kubectl cnpg restart postgresql-us-master -n postgres-db

# Create on-demand backup
kubectl cnpg backup postgresql-us-master -n postgres-db

# List backups
kubectl get backups -n postgres-db
```

### Links

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [PostgreSQL 17 Documentation](https://www.postgresql.org/docs/17/)
- [Project PostgreSQL Documentation](../../services/postgresql/)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-11-04 | Initial deployment of postgresql-us-master | System |
| 2025-11-04 | Created murror-be database for backend application | System |
