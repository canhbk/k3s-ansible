# VPS Management Database Connection Information - VN Production (postgresql-ha)

## Database Details
- **Database Name**: `vps-management`
- **Username**: `vps`
- **Password**: `<REPLACE_WITH_ACTUAL_PASSWORD>`
- **Owner**: vps user
- **Cluster**: postgresql-ha (PostgreSQL 17)
- **Namespace**: postgres-db
- **Environment**: PRODUCTION (VN cluster)

## Connection Endpoints

### Internal Access (within cluster)
- **Read/Write**: `postgresql-ha-rw.postgres-db.svc.cluster.local:5432`
- **Read-only**: `postgresql-ha-ro.postgres-db.svc.cluster.local:5432`
- **Any instance**: `postgresql-ha-r.postgres-db.svc.cluster.local:5432`

### External Access Options
1. **LoadBalancer Service**: `postgres-vps-management-ha`
   - Port: 5432
   - NodePort: 30308
   - External IPs: Will be assigned from pool (14.225.210.108, 14.225.210.165, 14.225.210.170)

2. **NodePort Service**: `postgresql-ha-external`
   - Port: 30432
   - Access via any node IP on port 30432

3. **Replication LoadBalancer**: `postgresql-ha-replication`
   - Port: 5434
   - External IPs: 14.225.210.108, 14.225.210.165, 14.225.210.170

## Connection String Examples

### Internal (from within the cluster)
```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-ha-rw.postgres-db.svc.cluster.local:5432/vps-management
```

### External via LoadBalancer (once IPs are assigned)
```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@<EXTERNAL-IP>:5432/vps-management
```

### External via NodePort
```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@<NODE-IP>:30432/vps-management
```

## Features
- PostgreSQL 17 (without pgvector extension)
- Storage: 5Gi on Longhorn storage class
- Node affinity: Requires nodes with `longhorn=true` label
- Healthy cluster status (unlike postgresql-pgvector)

## Verification Commands

```bash
# Check database status
kubectl get databases.postgresql.cnpg.io -n postgres-db | grep vps

# Check LoadBalancer service
kubectl get svc postgres-vps-management-ha -n postgres-db

# Check cluster status
kubectl describe clusters.postgresql.cnpg.io postgresql-ha -n postgres-db

# Connect to database from within cluster
kubectl run -it --rm --image=postgres:17 psql-test -- psql "postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-ha-rw.postgres-db.svc.cluster.local:5432/vps-management"
```

## Security Notes
- This is a PRODUCTION environment - strong passwords are mandatory
- External access is exposed via multiple services
- Consider implementing:
  - Firewall rules to restrict access
  - VPN connection for secure access
  - Regular password rotation
  - Connection encryption (SSL/TLS)

## Note
This database was created on postgresql-ha cluster because the postgresql-pgvector cluster has authentication issues preventing new database creation.