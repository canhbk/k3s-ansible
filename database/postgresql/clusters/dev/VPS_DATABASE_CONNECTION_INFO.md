# VPS Management Database Connection Information

## Database Details

- **Database Name**: `vps-management`
- **Username**: `vps`
- **Password**: `<REPLACE_WITH_ACTUAL_PASSWORD>`
- **Owner**: vps user
- **Cluster**: postgresql-ha
- **Namespace**: postgres-db

## Connection Endpoints

### Internal Access (within cluster)

- **Read/Write**: `postgresql-ha-rw.postgres-db.svc.cluster.local:5432`
- **Read-only**: `postgresql-ha-ro.postgres-db.svc.cluster.local:5432`
- **Any instance**: `postgresql-ha-r.postgres-db.svc.cluster.local:5432`

### External Access (LoadBalancer)

- **Service Name**: `postgres-vps-management`
- **Port**: 5432
- **NodePort**: 30883
- **Status**: Pending (LoadBalancer IPs are being assigned)

## Connection String Examples

### Internal (from within the cluster)

```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-ha-rw.postgres-db.svc.cluster.local:5432/vps-management
```

### External (once LoadBalancer IPs are assigned)

```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@<EXTERNAL-IP>:5432/vps-management
```

## Verification Commands

```bash
# Check database status
kubectl get databases.postgresql.cnpg.io -n postgres-db

# Check LoadBalancer service
kubectl get svc postgres-vps-management -n postgres-db

# Connect to database from within cluster
kubectl run -it --rm --image=postgres:17 psql-test -- psql "postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-ha-rw.postgres-db.svc.cluster.local:5432/vps-management"
```

## Notes

- The database is running on PostgreSQL 17 with pgvector extension
- The LoadBalancer service is configured for development use (open to internet)
- For production, consider implementing IP restrictions or using a private network
