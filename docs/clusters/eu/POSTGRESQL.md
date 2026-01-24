# PostgreSQL on EU Cluster

## Overview

PostgreSQL HA is deployed on the EU cluster as a permanent production database. It was restored from the VN cluster's Cloudflare R2 backup to establish the EU cluster's database.

**Key Details**:
- **Version**: PostgreSQL 17.5
- **Operator**: CloudNative-PG v1.26.0
- **Instances**: 1 (single instance)
- **Storage**: 5Gi on `longhorn-replicated` (2 replicas)
- **Source**: Restored from VN cluster backup

## Databases

| Database | Owner | Description |
|----------|-------|-------------|
| murror | be | Main application database (47 tables) |
| vps-management | vps | VPS management database (11 tables) |
| notifications | notifications | Murror notification service database |
| default | dev | Default database |
| app | app | Application database |

## Internal Access

The PostgreSQL service is available internally at:

- **Service**: `postgresql-ha-rw.postgres-db`
- **Port**: 5432
- **Connection String**: `postgresql://be:***@postgresql-ha-rw.postgres-db:5432/murror`

### Available Services

| Service | Type | Purpose |
|---------|------|---------|
| postgresql-ha-rw | ClusterIP | Read-Write (Primary) |
| postgresql-ha-ro | ClusterIP | Read-Only (Replicas) |
| postgresql-ha-r | ClusterIP | Any instance |

## Database Users

| Username | Role | Description |
|----------|------|-------------|
| postgres | Superuser | Database superuser |
| be | Application | Murror backend user |
| vps | Application | VPS management user |
| notifications | Application | Murror notification service user |
| dev | Application | Development user |
| app | Application | App user |

## Verification

```bash
# Check cluster status
kubectl --context eu get cluster postgresql-ha -n postgres-db

# Check pod status
kubectl --context eu get pods -n postgres-db

# Check services
kubectl --context eu get svc -n postgres-db

# List databases
kubectl --context eu exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "\l"

# List users
kubectl --context eu exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "\du"

# Check database sizes
kubectl --context eu exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datname NOT IN ('template0', 'template1');"
```

## Restore Information

This cluster was restored from VN cluster backup:

- **Source Cluster**: postgresql-ha (VN)
- **Restore Date**: 2025-12-08
- **Backup Source**: Cloudflare R2 (`s3://murror-api-prod-postgres-backup/postgresql-ha-vn`)
- **Backup Time**: 2025-12-08 10:35:01 UTC (latest available)
- **Restore Method**: CloudNativePG recovery bootstrap

### Data Verification (at restore time)

| Metric | EU (Restored) | VN (Source) |
|--------|---------------|-------------|
| Users table | 543 rows | 543 rows |
| Connections table | 44 rows | 44 rows |
| murror database | 15 MB | 15 MB |
| vps-management database | 8747 kB | 8747 kB |
| murror tables | 47 | 47 |

## Backup Configuration

**Note**: This cluster does not have ongoing backups configured. It was restored from VN cluster backup for permanent EU deployment.

If you need to set up backups for this cluster, see the VN cluster's backup configuration in `database/postgresql/clusters/vn/cluster.yaml` as a reference.

## Configuration Files

EU PostgreSQL configuration is located at:
- `database/postgresql/clusters/eu/cluster.yaml` - Cluster definition
- `database/postgresql/clusters/eu/secrets.yaml` - User credentials
- `database/postgresql/clusters/eu/secrets-r2-backup.yaml` - R2 credentials (for restore)
- `database/postgresql/clusters/eu/secrets-vps-ha.yaml` - VPS user credentials
- `database/postgresql/clusters/eu/secrets-notifications.yaml` - Notifications service credentials

## Troubleshooting

### Check cluster status
```bash
kubectl --context eu get cluster postgresql-ha -n postgres-db -o yaml
```

### View PostgreSQL logs
```bash
kubectl --context eu logs -n postgres-db postgresql-ha-1 -c postgres -f
```

### Connect to psql shell
```bash
kubectl --context eu exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres
```

### Test database connectivity
```bash
kubectl --context eu run psql-test --rm -i --tty --image=postgres:17 -- psql \
  -h postgresql-ha-rw.postgres-db.svc.cluster.local \
  -U postgres -c "SELECT current_database(), current_user, version();"
```

---

## Last Updated

- Date: 2025-12-22
- Status: Healthy
- Instances: 1
- Restore Source: VN cluster (Cloudflare R2)
- Changes: Added notifications database and user for Murror notification service
